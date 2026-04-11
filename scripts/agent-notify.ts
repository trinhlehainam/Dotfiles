import { closeSync, openSync, writeSync } from "node:fs";
import { parseArgs as nodeParseArgs } from "node:util";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ClaudeHookInput {
  session_id: string;
  transcript_path?: string;
  cwd?: string;
  permission_mode?: string;
  hook_event_name: string;
  message?: string;
  title?: string;
  notification_type?: string;
  stop_reason?: string;
}

export interface ParsedNotification {
  title: string;
  body: string;
  source: string;
  event: string;
  cwd?: string;
}

export interface ParsedCliArgs {
  title?: string;
  body?: string;
  stdin: boolean;
}

// ---------------------------------------------------------------------------
// Pure helpers (exported for testing)
// ---------------------------------------------------------------------------

/** Extract project name from cwd path */
export function projectName(cwd?: string): string {
  if (!cwd) return "";
  const parts = cwd.replace(/\/+$/, "").split("/");
  return parts[parts.length - 1] ?? "";
}

/** Map notification_type to human-readable label */
export function notificationTypeLabel(type?: string): string {
  switch (type) {
    case "permission_prompt":
      return "Permission required";
    case "idle_prompt":
      return "Awaiting input";
    case "auth_success":
      return "Auth succeeded";
    case "elicitation_dialog":
      return "Question";
    default:
      return "Notification";
  }
}

/** Sanitize text interpolated into OSC 777 fields — strip controls and escape semicolons */
export function sanitizeOscField(value: string): string {
  return value
    .replace(/[\x00-\x1F\x7F]/g, "")
    .replace(/;/g, ":");
}

/** Build OSC 777 escape sequence */
export function buildOsc777(title: string, body: string): string {
  return `\x1b]777;notify;${sanitizeOscField(title)};${sanitizeOscField(body)}\x07`;
}

/** DCS-wrap an escape sequence for tmux passthrough */
export function wrapForTmux(sequence: string, isTmux: boolean): string {
  if (!isTmux) return sequence;
  return `\x1bPtmux;\x1b${sequence.replace(/\x1b/g, "\x1b\x1b")}\x1b\\`;
}

/** Format Claude Code hook input into rich notification */
export function formatClaudeHook(input: ClaudeHookInput): ParsedNotification {
  const project = projectName(input.cwd);
  const projectLabel = project ? ` \u2014 ${project}` : "";

  switch (input.hook_event_name) {
    case "Notification": {
      const typeLabel = notificationTypeLabel(input.notification_type);
      return {
        title: `Claude Code${projectLabel}`,
        body: `${typeLabel}: ${input.message ?? "Notification"}`,
        source: "claude",
        event: input.notification_type ?? "notification",
        cwd: input.cwd,
      };
    }
    case "Stop": {
      return {
        title: `Claude Code${projectLabel}`,
        body: "Task complete",
        source: "claude",
        event: "stop",
        cwd: input.cwd,
      };
    }
    case "SubagentStop": {
      return {
        title: `Claude Code${projectLabel}`,
        body: "Subagent finished",
        source: "claude",
        event: "subagent_stop",
        cwd: input.cwd,
      };
    }
    default: {
      return {
        title: `Claude Code${projectLabel}`,
        body: input.message ?? input.hook_event_name,
        source: "claude",
        event: input.hook_event_name,
        cwd: input.cwd,
      };
    }
  }
}

/** Parse CLI arguments using Node.js built-in util.parseArgs */
export function parseArgs(args: string[]): ParsedCliArgs {
  const { values, positionals } = nodeParseArgs({
    args,
    options: {
      stdin: { type: "boolean" },
      title: { type: "string", short: "t" },
      body: { type: "string", short: "b" },
    },
    strict: false,
    allowPositionals: true,
  });

  const title = values.title ?? positionals[0];
  const body = values.body ?? (positionals.length > 1 && !values.title ? positionals[1] : undefined);

  return {
    stdin: !!values.stdin,
    title: title as string | undefined,
    body: body as string | undefined,
  };
}

// ---------------------------------------------------------------------------
// I/O helpers (side-effecting, not exported)
// ---------------------------------------------------------------------------

/** Send terminal bell to /dev/tty */
function sendBell(): void {
  writeToTty("\x07");
}

/** Write raw bytes to /dev/tty (fallback to stderr) */
function writeToTty(data: string): void {
  try {
    const fd = openSync("/dev/tty", "w");
    writeSync(fd, data);
    closeSync(fd);
  } catch {
    process.stderr.write(data);
  }
}

/** Send OSC 777 notification toast */
function sendOsc777(title: string, body: string): void {
  const isTmux = !!process.env.TMUX;
  const osc = buildOsc777(title, body);
  const out = wrapForTmux(osc, isTmux);
  writeToTty(out);
}


// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = "";
    let settled = false;
    if (process.stdin.isTTY) {
      resolve(data);
      return;
    }
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk: string) => {
      data += chunk;
    });
    const timer = setTimeout(() => {
      if (!settled) { settled = true; resolve(data); }
    }, 2000);
    process.stdin.on("end", () => {
      clearTimeout(timer);
      if (!settled) { settled = true; resolve(data); }
    });
  });
}

export async function main(): Promise<void> {
  const parsed = parseArgs(process.argv.slice(2));

  let notification: ParsedNotification;

  if (parsed.stdin) {
    try {
      const input = await readStdin();
      notification = formatClaudeHook(JSON.parse(input) as ClaudeHookInput);
    } catch {
      notification = { title: "Notification", body: "Agent event", source: "unknown", event: "unknown" };
    }
  } else if (parsed.title) {
    notification = {
      title: parsed.title,
      body: parsed.body ?? "",
      source: "manual",
      event: "manual",
    };
  } else {
    try {
      const input = await readStdin();
      if (input.trim()) {
        const json = JSON.parse(input);
        if ("hook_event_name" in json) {
          notification = formatClaudeHook(json as ClaudeHookInput);
        } else {
          notification = { title: "Notification", body: input.trim(), source: "unknown", event: "unknown" };
        }
      } else {
        notification = { title: "Notification", body: "Agent event", source: "unknown", event: "unknown" };
      }
    } catch {
      notification = { title: "Notification", body: "Agent event", source: "unknown", event: "unknown" };
    }
  }

  sendBell();
  sendOsc777(notification.title, notification.body);
}

if (import.meta.main) {
  await main().catch((err: Error) => {
    process.stderr.write(`agent-notify error: ${err.message}\n`);
    process.exit(1);
  });
}
