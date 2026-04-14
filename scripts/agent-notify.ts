import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { text as readStreamText } from "node:stream/consumers";
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

/** Codex CLI notify payload — passed as single argv JSON argument. */
export interface CodexNotifyPayload {
  /** Event type. Known type is "agent-turn-complete", but unknown types still format generically. */
  type: string;
  "thread-id"?: string;
  "turn-id"?: string;
  cwd?: string;
  "input-messages"?: string[];
  "last-assistant-message"?: string;
  client?: string;
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
  format: "auto" | "claude" | "codex";
  positionals: string[];
}

export interface TmuxClientInfo {
  termname: string;
  termtype: string;
}

export interface NotificationTransport {
  preferTmuxPaneTty: boolean;
  allowOsc777: boolean;
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

/** Detect Codex CLI notify payloads by checking for Codex-specific fields. */
export function isCodexNotifyPayload(value: unknown): value is CodexNotifyPayload {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Partial<CodexNotifyPayload>;
  return typeof candidate.type === "string"
    && (typeof candidate["thread-id"] === "string"
      || typeof candidate["turn-id"] === "string");
}

/** Format Codex CLI notify payload into a standard notification. */
export function formatCodexEvent(payload: CodexNotifyPayload): ParsedNotification {
  const project = projectName(payload.cwd);
  const projectLabel = project ? ` \u2014 ${project}` : "";

  switch (payload.type) {
    case "agent-turn-complete":
      return {
        title: `Codex${projectLabel}`,
        body: "Task complete",
        source: "codex",
        event: payload.type,
        cwd: payload.cwd,
      };
    default:
      return {
        title: `Codex${projectLabel}`,
        body: payload["last-assistant-message"] ?? payload.type,
        source: "codex",
        event: payload.type,
        cwd: payload.cwd,
      };
  }
}

/** Sanitize text interpolated into OSC 777 fields — strip controls and escape semicolons */
export function sanitizeOscField(value: string): string {
  let sanitized = "";

  for (const character of value) {
    const code = character.charCodeAt(0);
    if ((code >= 0 && code <= 31) || (code >= 127 && code <= 159)) {
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
  return `${ESC}Ptmux;${sequence.replaceAll(ESC, `${ESC}${ESC}`)}${ST}`;
}

/** Parse a `tmux list-clients -F '#{client_termname}|#{client_termtype}'` line. */
export function parseTmuxClientInfo(line: string): TmuxClientInfo | null {
  const [termname = "", termtype = ""] = line.trim().split("|");
  if (!termname && !termtype) {
    return null;
  }

  return { termname, termtype };
}

/** Parse a `tmux list-clients -F '#{client_tty}|#{client_termname}|#{client_termtype}'` line. */
export function parseClientLine(
  line: string,
): { tty: string; termname: string; termtype: string } | null {
  const [tty = "", termname = "", termtype = ""] = line.trim().split("|");
  if (!tty) return null;
  return { tty, termname, termtype };
}

/** Build notification bytes for one tmux client TTY. */
export function clientNotificationSequence(
  title: string,
  body: string,
  client: { termname: string; termtype: string },
): string {
  return supportsOsc777ViaTmuxClientInfo(client)
    ? `${BEL}${buildOsc777(title, body)}`
    : BEL;
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

/** Neovim terminal jobs are rendered by libvterm, not by the outer terminal directly. */
export function isEmbeddedNvimTerminal(env: NodeJS.ProcessEnv): boolean {
  return env.NVIM !== undefined;
}

/** Only emit OSC 777 for known WezTerm sessions. BEL remains the universal fallback. */
export function supportsOsc777(
  env: NodeJS.ProcessEnv,
  tmuxClientInfo: TmuxClientInfo | null = null,
): boolean {
  if (isEmbeddedNvimTerminal(env) && env.TMUX_PANE === undefined) {
    return false;
  }

  if (env.TMUX) {
    return supportsOsc777ViaTmuxClientInfo(tmuxClientInfo);
  }

  return env.TERM_PROGRAM === "WezTerm"
    || env.WEZTERM_PANE !== undefined
    || env.WEZTERM_EXECUTABLE !== undefined
}

/** Decide which terminal path is safe for notifications in the current process. */
export function selectNotificationTransport(
  env: NodeJS.ProcessEnv,
  tmuxClientInfo: TmuxClientInfo | null = null,
): NotificationTransport {
  const preferTmuxPaneTty = isEmbeddedNvimTerminal(env) && env.TMUX_PANE !== undefined;

  return {
    preferTmuxPaneTty,
    allowOsc777: supportsOsc777(env, tmuxClientInfo),
  };
}

/** Build the terminal control sequence for one notification. */
export function buildTerminalNotification(
  title: string,
  body: string,
  env: NodeJS.ProcessEnv = process.env,
  tmuxClientInfo: TmuxClientInfo | null = null,
): string {
  return terminalNotificationSequence(
    title,
    body,
    selectNotificationTransport(env, tmuxClientInfo),
    !!env.TMUX,
  );
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
      format: { type: "string" },
    },
    strict: false,
    allowPositionals: true,
  });

  const rawFormat = stringOption(values.format as string | string[] | undefined);
  const format: "auto" | "claude" | "codex" = rawFormat === "claude" || rawFormat === "codex" ? rawFormat : "auto";

  if (format === "codex") {
    return { stdin: !!values.stdin, format, positionals };
  }

  const explicitTitle = stringOption(values.title as string | string[] | undefined);
  const explicitBody = stringOption(values.body as string | string[] | undefined);
  const title = explicitTitle ?? positionals[0];
  const body = explicitBody ?? (positionals.length > 1 && explicitTitle === undefined ? positionals[1] : undefined);

  return {
    stdin: !!values.stdin,
    title,
    body,
    format,
    positionals,
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

function stringOption(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value.at(-1) : value;
}

function terminalNotificationSequence(
  title: string,
  body: string,
  transport: Pick<NotificationTransport, "allowOsc777">,
  isTmux: boolean,
): string {
  if (!transport.allowOsc777) {
    return BEL;
  }

  return `${BEL}${wrapForTmux(buildOsc777(title, body), isTmux)}`;
}

function terminalDevicePath(): string {
  return process.platform === "win32" ? "CONOUT$" : "/dev/tty";
}

function tmuxCapture(args: string[]): string | null {
  try {
    const output = execFileSync(
      "tmux",
      args,
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
    return output || null;
  } catch {
    return null;
  }
}

function tmuxDisplayValue(format: string): string | null {
  const paneId = process.env.TMUX_PANE;
  if (!paneId) {
    return null;
  }

  return tmuxCapture(["display-message", "-p", "-t", paneId, format]);
}

function currentPaneTtyPath(): string | null {
  return tmuxDisplayValue("#{pane_tty}");
}

function currentSessionId(): string | null {
  return tmuxDisplayValue("#{session_id}");
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
    const output = tmuxCapture(args);
    if (output === null) {
      return null;
    }

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

function writeToPath(path: string, data: string): boolean {
  try {
    writeFileSync(path, data, { flag: "w" });
    return true;
  } catch {
    return false;
  }
}

/** Write notification bytes directly to every tmux client TTY (cross-session support). */
function notifyTmuxClients(title: string, body: string): boolean {
  if (!process.env.TMUX) return false;

  const output = tmuxCapture([
    "list-clients",
    "-F",
    "#{client_tty}|#{client_termname}|#{client_termtype}",
  ]);
  if (!output) return false;

  let notified = false;

  for (const line of output.split(/\r?\n/)) {
    const client = parseClientLine(line);
    if (!client) continue;
    const sequence = clientNotificationSequence(title, body, client);

    if (writeToPath(client.tty, sequence)) {
      notified = true;
    }
  }

  return notified;
}

/** Write raw bytes to the safest available terminal endpoint. */
function writeToTerminal(data: string, transport: NotificationTransport): void {
  const paneTtyPath = currentPaneTtyPath();

  // Neovim terminal buffers are rendered by libvterm, so pane PTY output is the
  // only reliable route back to the outer terminal when tmux is available.
  if (transport.preferTmuxPaneTty && paneTtyPath && writeToPath(paneTtyPath, data)) {
    return;
  }

  if (writeToPath(terminalDevicePath(), data)) {
    return;
  }

  if (!transport.preferTmuxPaneTty && paneTtyPath && writeToPath(paneTtyPath, data)) {
    return;
  }

  if (process.stderr.isTTY) {
    process.stderr.write(data);
  }
}

function isClaudeHookInput(value: unknown): value is ClaudeHookInput {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  const candidate = value as Partial<Record<keyof ClaudeHookInput, unknown>>;
  return typeof candidate.hook_event_name === "string" && typeof candidate.session_id === "string";
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

function parseCodexArgv(argvJson: string | undefined): ParsedNotification {
  if (!argvJson) return defaultNotification();
  try {
    const parsed = JSON.parse(argvJson) as unknown;
    if (isCodexNotifyPayload(parsed)) return formatCodexEvent(parsed);
  } catch {
    // fall through
  }
  return defaultNotification();
}

function sendNotification(notification: ParsedNotification): void {
  // Try broadcasting directly to tmux client TTYs first (cross-session support)
  if (!notifyTmuxClients(notification.title, notification.body)) {
    // Fallback: original behavior (agent's own controlling TTY / pane TTY)
    const tmuxClientInfo = detectTmuxClientInfo();
    const transport = selectNotificationTransport(process.env, tmuxClientInfo);
    writeToTerminal(
      terminalNotificationSequence(notification.title, notification.body, transport, !!process.env.TMUX),
      transport,
    );
  }
}


// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function readStdin(): Promise<string> {
  if (process.stdin.isTTY) {
    return "";
  }

  try {
    return await readStreamText(process.stdin);
  } catch {
    return "";
  }
}

export async function main(): Promise<void> {
  const parsed = parseArgs(process.argv.slice(2));

  let notification: ParsedNotification;

  if (parsed.format === "codex") {
    notification = parseCodexArgv(parsed.positionals[0]);
  } else if (parsed.format === "claude" || parsed.stdin) {
    notification = parseNotificationFromStdin(await readStdin(), true);
  } else {
    // auto mode: Claude stdin → Codex argv → manual title/body → default
    const stdinText = await readStdin();

    if (stdinText.trim()) {
      notification = parseNotificationFromStdin(stdinText, false);
    } else if (parsed.title) {
      // No stdin — check if title is actually a Codex JSON payload
      const maybeCodexTitle = parsed.title.trimStart();
      const codex = maybeCodexTitle.startsWith("{")
        ? parseCodexArgv(parsed.title)
        : defaultNotification();
      if (codex.source === "codex") {
        notification = codex;
      } else {
        notification = {
          title: parsed.title,
          body: parsed.body ?? "",
          source: "manual",
          event: "manual",
        };
      }
    } else {
      notification = defaultNotification();
    }
  }

  sendNotification(notification);
}

if (import.meta.main) {
  await main().catch((err: Error) => {
    process.stderr.write(`agent-notify error: ${err.message}\n`);
    process.exit(1);
  });
}
