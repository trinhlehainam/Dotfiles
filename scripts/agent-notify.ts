import { execFileSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, statSync, unlinkSync, writeFileSync } from "node:fs";
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

export interface OpenCodeSessionState {
  project: string;
  cwd?: string;
  model?: string;
  lastText?: string;
  lastTool?: string;
  errored?: boolean;
  notifiedPermissions: string[];
  updatedAt: number;
}

export interface ParsedCliArgs {
  title?: string;
  body?: string;
  stdin: boolean;
  format: "auto" | "claude" | "codex" | "opencode-event";
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

/** Clip text to max characters with ellipsis. */
export function clip(value: string, max = 140): string {
  const trimmed = value.replace(/\s+/g, " ").trim();
  if (max <= 3) return trimmed.slice(0, max);
  return trimmed.length > max ? `${trimmed.slice(0, max - 3)}...` : trimmed;
}

/** Extract sessionID from any OpenCode event shape. */
export function extractSessionId(event: unknown): string | null {
  if (typeof event !== "object" || event === null) return null;
  const candidate = event as Record<string, unknown>;
  const props = candidate.properties;
  if (typeof props === "object" && props !== null) {
    const sid = (props as Record<string, unknown>).sessionID;
    if (typeof sid === "string") return sid;
  }
  return null;
}

/** Check if a value looks like an OpenCode event `{ type, properties }`. */
export function isOpenCodeEvent(value: unknown): boolean {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return typeof candidate.type === "string" && typeof candidate.properties === "object" && candidate.properties !== null;
}

/** Format permission display text from OpenCode event properties. */
export function formatOpenCodePermissionBody(props: Record<string, unknown>): string {
  if (typeof props.title === "string" && props.title !== "") return props.title;

  const kind = (typeof props.type === "string" ? props.type : null)
    ?? (typeof props.permission === "string" ? props.permission : null)
    ?? "permission";

  const rawPattern = Array.isArray(props.pattern)
    ? props.pattern.join(", ")
    : typeof props.pattern === "string"
      ? props.pattern
      : Array.isArray(props.patterns)
        ? (props.patterns as string[]).join(", ")
        : null;

  return rawPattern ? `${kind} (${rawPattern})` : kind;
}

/** Build "OpenCode — project" label from session state. */
export function opencodeProjectLabel(state: OpenCodeSessionState | null): string {
  if (!state) return "OpenCode";
  const project = projectName(state.cwd) || state.project;
  return project ? `OpenCode \u2014 ${project}` : "OpenCode";
}

/** Create a fresh session state. */
export function createSessionState(project = ""): OpenCodeSessionState {
  return { project, notifiedPermissions: [], updatedAt: Date.now() };
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
  const format: ParsedCliArgs["format"] = rawFormat === "claude" || rawFormat === "codex" || rawFormat === "opencode-event"
    ? rawFormat
    : "auto";

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

// ---------------------------------------------------------------------------
// OpenCode session state file management
// ---------------------------------------------------------------------------

const SESSION_STATE_SUBDIR = "opencode-sessions";
const STALE_SESSION_MAX_AGE_MS = 30 * 60 * 1000; // 30 minutes

export function sessionStateDir(baseDir?: string): string {
  const base = baseDir ?? (process.env.TMPDIR || "/tmp");
  const dir = `${base}/${SESSION_STATE_SUBDIR}`;
  try {
    mkdirSync(dir, { recursive: true });
  } catch {
    // best effort
  }
  return dir;
}

export function sessionStatePath(sessionID: string, baseDir?: string): string {
  // Sanitize sessionID for use as filename
  const safe = sessionID.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `${sessionStateDir(baseDir)}/${safe}.json`;
}

export function loadSessionState(sessionID: string, baseDir?: string): OpenCodeSessionState | null {
  try {
    const data = readFileSync(sessionStatePath(sessionID, baseDir), "utf8");
    return JSON.parse(data) as OpenCodeSessionState;
  } catch {
    return null;
  }
}

export function saveSessionState(sessionID: string, state: OpenCodeSessionState, baseDir?: string): void {
  try {
    state.updatedAt = Date.now();
    writeFileSync(sessionStatePath(sessionID, baseDir), JSON.stringify(state), "utf8");
  } catch {
    // best effort
  }
}

export function deleteSessionState(sessionID: string, baseDir?: string): void {
  try {
    unlinkSync(sessionStatePath(sessionID, baseDir));
  } catch {
    // best effort
  }
}

export function cleanStaleSessions(maxAgeMs = STALE_SESSION_MAX_AGE_MS, baseDir?: string): void {
  const dir = sessionStateDir(baseDir);
  try {
    const entries = readdirSync(dir);
    const cutoff = Date.now() - maxAgeMs;
    for (const entry of entries) {
      if (!entry.endsWith(".json")) continue;
      try {
        const stat = statSync(`${dir}/${entry}`);
        if (stat.mtimeMs < cutoff) {
          unlinkSync(`${dir}/${entry}`);
        }
      } catch {
        // skip
      }
    }
  } catch {
    // best effort
  }
}

// ---------------------------------------------------------------------------
// OpenCode event processing
// ---------------------------------------------------------------------------

export function processOpenCodeEvent(
  raw: unknown,
  baseDir?: string,
): { notification?: ParsedNotification; stateId?: string } | null {
  if (!isOpenCodeEvent(raw)) return null;

  const event = raw as { type: string; properties: Record<string, unknown> };
  const { type, properties } = event;

  const sessionID = extractSessionId(event);
  cleanStaleSessions(STALE_SESSION_MAX_AGE_MS, baseDir);

  // --- Intermediate events: accumulate session state ---

  if (type === "message.updated") {
    const info = properties.info as Record<string, unknown> | undefined;
    if (!info || info.role !== "assistant") return null;
    const path = info.path as Record<string, unknown> | undefined;
    const sid = (info.sessionID as string) ?? sessionID;
    if (!sid) return null;

    const state = loadSessionState(sid, baseDir) ?? createSessionState();
    if (path?.cwd && typeof path.cwd === "string") state.cwd = path.cwd;
    if (typeof info.providerID === "string" && typeof info.modelID === "string") {
      state.model = `${info.providerID}/${info.modelID}`;
    }
    saveSessionState(sid, state, baseDir);
    return { stateId: sid };
  }

  if (type === "message.part.updated") {
    const part = properties.part as Record<string, unknown> | undefined;
    if (!part) return null;
    const sid = (part.sessionID as string) ?? sessionID;
    if (!sid) return null;

    const state = loadSessionState(sid, baseDir) ?? createSessionState();

    if (part.type === "text" && typeof part.text === "string") {
      const time = part.time as Record<string, unknown> | undefined;
      if (time?.end) {
        state.lastText = clip(part.text as string);
      }
    }

    if (part.type === "tool") {
      const pstate = part.state as Record<string, unknown> | undefined;
      const status = pstate?.status;
      if (status === "completed" || status === "error") {
        state.lastTool = `${part.tool ?? "tool"} ${status}`;
      }
    }

    saveSessionState(sid, state, baseDir);
    return { stateId: sid };
  }

  // --- Permission events: render immediately ---

  if (type === "permission.asked" || type === "permission.updated") {
    const permId = properties.id as string | undefined;
    const sid = sessionID;
    const state = sid ? loadSessionState(sid, baseDir) : null;

    // Dedupe by permission ID
    if (permId && state?.notifiedPermissions.includes(permId)) return null;

    const body = `Permission required: ${formatOpenCodePermissionBody(properties)}`;
    const notification: ParsedNotification = {
      title: opencodeProjectLabel(state),
      body,
      source: "opencode",
      event: type,
      cwd: state?.cwd,
    };

    // Record permission ID for dedupe
    if (permId && sid) {
      const st = state ?? createSessionState();
      st.notifiedPermissions.push(permId);
      saveSessionState(sid, st, baseDir);
    }

    return { notification, stateId: sid ?? undefined };
  }

  // --- Terminal events: render and clean up ---

  if (type === "session.idle" || (type === "session.status" && (properties.status as Record<string, unknown>)?.type === "idle")) {
    if (!sessionID) return null;
    const state = loadSessionState(sessionID, baseDir);

    // Suppress stale idle after error
    if (state?.errored) {
      deleteSessionState(sessionID, baseDir);
      return null;
    }

    const detail = state?.lastText ?? state?.lastTool ?? "Task complete";
    const body = state?.model ? `${state.model} \u00b7 ${detail}` : detail;
    const notification: ParsedNotification = {
      title: opencodeProjectLabel(state ?? null),
      body,
      source: "opencode",
      event: type,
      cwd: state?.cwd,
    };

    deleteSessionState(sessionID, baseDir);
    return { notification, stateId: sessionID };
  }

  if (type === "session.error") {
    if (!sessionID) return null;
    const state = loadSessionState(sessionID, baseDir);

    // Don't double-notify if already errored
    if (state?.errored) {
      deleteSessionState(sessionID, baseDir);
      return null;
    }

    const errorData = properties.error as Record<string, unknown> | undefined;
    const errorMsg = errorData?.data && typeof (errorData.data as Record<string, unknown>).message === "string"
      ? (errorData.data as Record<string, unknown>).message as string
      : undefined;
    const lastDetail = state?.lastText;
    const body = lastDetail
      ? `Session error${errorMsg ? ` (${errorMsg})` : ""} after: ${lastDetail}`
      : `Session error${errorMsg ? `: ${errorMsg}` : ""}`;

    const notification: ParsedNotification = {
      title: opencodeProjectLabel(state ?? null),
      body,
      source: "opencode",
      event: "session.error",
      cwd: state?.cwd,
    };

    deleteSessionState(sessionID, baseDir);
    return { notification, stateId: sessionID };
  }

  // Unknown event — no-op
  return null;
}

function sendNotification(notification: ParsedNotification): void {
  const tmuxClientInfo = detectTmuxClientInfo();
  const transport = selectNotificationTransport(process.env, tmuxClientInfo);
  writeToTerminal(
    terminalNotificationSequence(notification.title, notification.body, transport, !!process.env.TMUX),
    transport,
  );
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
  } else if (parsed.format === "opencode-event") {
    const stdinText = await readStdin();
    if (stdinText.trim()) {
      try {
        const raw = JSON.parse(stdinText.trim()) as unknown;
        const result = processOpenCodeEvent(raw);
        if (result?.notification) {
          sendNotification(result.notification);
        }
        return;
      } catch {
        return;
      }
    }
    return;
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
