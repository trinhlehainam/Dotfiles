import { execFileSync } from "node:child_process";
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
  error?: string;
  tool_name?: string;
  tool_input?: Record<string, unknown>;
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

export interface TmuxClientInfo {
  termname: string;
  termtype: string;
}

const ESC = String.fromCharCode(27);
const BEL = String.fromCharCode(7);
const ST = `${ESC}\\`;

// ---------------------------------------------------------------------------
// Pure helpers (exported for testing)
// ---------------------------------------------------------------------------

/** Extract project name from cwd path */
export function projectName(cwd?: string): string {
  if (!cwd) return "";
  const parts = cwd.replace(/[\\/]+$/, "").split(/[\\/]/);
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
  let sanitized = "";

  for (const character of value) {
    const code = character.charCodeAt(0);
    if ((code >= 0 && code <= 31) || code === 127) {
      continue;
    }

    sanitized += character === ";" ? ":" : character;
  }

  return sanitized;
}

/** Build OSC 777 escape sequence */
export function buildOsc777(title: string, body: string): string {
  return `${ESC}]777;notify;${sanitizeOscField(title)};${sanitizeOscField(body)}${ST}`;
}

/** DCS-wrap an escape sequence for tmux passthrough */
export function wrapForTmux(sequence: string, isTmux: boolean): string {
  if (!isTmux) return sequence;
  return `${ESC}Ptmux;${ESC}${sequence.split(ESC).join(`${ESC}${ESC}`)}${ST}`;
}

/** Parse a `tmux list-clients -F '#{client_termname}|#{client_termtype}'` line. */
export function parseTmuxClientInfo(line: string): TmuxClientInfo | null {
  const [termname = "", termtype = ""] = line.trim().split("|");
  if (!termname && !termtype) {
    return null;
  }

  return { termname, termtype };
}

/** Only enable WezTerm-specific OSC when every attached client for a session supports it. */
export function selectTmuxClientInfo(clientInfos: TmuxClientInfo[]): TmuxClientInfo | null {
  if (clientInfos.length === 0) {
    return null;
  }

  return clientInfos.every((clientInfo) => supportsOsc777ViaTmuxClientInfo(clientInfo))
    ? clientInfos[0] ?? null
    : null;
}

/** Detect WezTerm via tmux client metadata when running inside tmux. */
export function supportsOsc777ViaTmuxClientInfo(clientInfo: TmuxClientInfo | null): boolean {
  if (clientInfo === null) {
    return false;
  }

  return clientInfo.termname === "wezterm" || clientInfo.termtype.startsWith("WezTerm ");
}

/** Only emit OSC 777 for known WezTerm sessions. BEL remains the universal fallback. */
export function supportsOsc777(
  env: NodeJS.ProcessEnv,
  tmuxClientInfo: TmuxClientInfo | null = null,
): boolean {
  return env.TERM_PROGRAM === "WezTerm"
    || env.WEZTERM_PANE !== undefined
    || env.WEZTERM_EXECUTABLE !== undefined
    || supportsOsc777ViaTmuxClientInfo(tmuxClientInfo);
}

/** Build the terminal control sequence for one notification. */
export function buildTerminalNotification(
  title: string,
  body: string,
  env: NodeJS.ProcessEnv = process.env,
  tmuxClientInfo: TmuxClientInfo | null = null,
): string {
  if (!supportsOsc777(env, tmuxClientInfo)) {
    return BEL;
  }

  return `${BEL}${wrapForTmux(buildOsc777(title, body), !!env.TMUX)}`;
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
        body: `${typeLabel}: ${input.message ?? input.title ?? "Notification"}`,
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
    case "StopFailure": {
      return {
        title: `Claude Code${projectLabel}`,
        body: input.error ? `Task failed: ${input.error}` : "Task failed",
        source: "claude",
        event: "stop_failure",
        cwd: input.cwd,
      };
    }
    case "PermissionRequest": {
      const tool = input.tool_name ?? "tool";
      const cmd = typeof input.tool_input?.command === "string"
        ? input.tool_input.command
        : "";
      const body = cmd ? `${tool}: ${cmd.length > 80 ? cmd.slice(0, 77) + "..." : cmd}` : `Permission: ${tool}`;
      return {
        title: `Claude Code${projectLabel}`,
        body,
        source: "claude",
        event: "permission_request",
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
        body: input.message ?? input.title ?? input.hook_event_name,
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

function defaultNotification(): ParsedNotification {
  return {
    title: "Notification",
    body: "Agent event",
    source: "unknown",
    event: "unknown",
  };
}

function terminalDevicePath(): string {
  return process.platform === "win32" ? "CONOUT$" : "/dev/tty";
}

function currentPaneTtyPath(): string | null {
  const paneId = process.env.TMUX_PANE;
  if (!paneId) {
    return null;
  }

  try {
    const tty = execFileSync(
      "tmux",
      ["display-message", "-p", "-t", paneId, "#{pane_tty}"],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
    return tty || null;
  } catch {
    return null;
  }
}

function currentSessionId(): string | null {
  const paneId = process.env.TMUX_PANE;
  if (!paneId) {
    return null;
  }

  try {
    const sessionId = execFileSync(
      "tmux",
      ["display-message", "-p", "-t", paneId, "#{session_id}"],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
    return sessionId || null;
  } catch {
    return null;
  }
}

function detectTmuxClientInfo(): TmuxClientInfo | null {
  if (!process.env.TMUX) {
    return null;
  }

  try {
    const sessionId = currentSessionId();
    const args = sessionId
      ? ["list-clients", "-t", sessionId, "-F", "#{client_termname}|#{client_termtype}"]
      : ["list-clients", "-F", "#{client_termname}|#{client_termtype}"];
    const output = execFileSync(
      "tmux",
      args,
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    );

    const clientInfos: TmuxClientInfo[] = [];
    for (const line of output.split(/\r?\n/)) {
      const parsed = parseTmuxClientInfo(line);
      if (parsed !== null) {
        clientInfos.push(parsed);
      }
    }

    return selectTmuxClientInfo(clientInfos);
  } catch {
    return null;
  }
}

/** Write raw bytes to the controlling terminal. */
function writeToTerminal(data: string): void {
  try {
    const fd = openSync(terminalDevicePath(), "w");
    try {
      writeSync(fd, data);
    } finally {
      closeSync(fd);
    }
  } catch {
    const paneTtyPath = currentPaneTtyPath();
    if (paneTtyPath) {
      try {
        const fd = openSync(paneTtyPath, "w");
        try {
          writeSync(fd, data);
          return;
        } finally {
          closeSync(fd);
        }
      } catch {
        // Fall through to stderr TTY fallback.
      }
    }

    if (process.stderr.isTTY) {
      process.stderr.write(data);
    }
  }
}

function isClaudeHookInput(value: unknown): value is ClaudeHookInput {
  return typeof value === "object" && value !== null && "hook_event_name" in value;
}

function parseNotificationFromStdin(input: string, strictJson: boolean): ParsedNotification {
  const trimmed = input.trim();

  if (!trimmed) {
    return defaultNotification();
  }

  try {
    const parsed = JSON.parse(trimmed) as unknown;

    if (isClaudeHookInput(parsed)) {
      return formatClaudeHook(parsed);
    }

    if (strictJson) {
      return defaultNotification();
    }
  } catch {
    if (strictJson) {
      return defaultNotification();
    }
  }

  return {
    title: "Notification",
    body: trimmed,
    source: "unknown",
    event: "unknown",
  };
}

function sendNotification(notification: ParsedNotification): void {
  writeToTerminal(
    buildTerminalNotification(
      notification.title,
      notification.body,
      process.env,
      detectTmuxClientInfo(),
    ),
  );
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
    notification = parseNotificationFromStdin(await readStdin(), true);
  } else if (parsed.title) {
    notification = {
      title: parsed.title,
      body: parsed.body ?? "",
      source: "manual",
      event: "manual",
    };
  } else {
    notification = parseNotificationFromStdin(await readStdin(), false);
  }

  sendNotification(notification);
}

if (import.meta.main) {
  await main().catch((err: Error) => {
    process.stderr.write(`agent-notify error: ${err.message}\n`);
    process.exit(1);
  });
}
