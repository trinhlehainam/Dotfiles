import { describe, expect, test } from "bun:test";

import {
  buildTerminalNotification,
  buildOsc777,
  clientNotificationSequence,
  formatClaudeHook,
  formatCodexEvent,
  isCodexNotifyPayload,
  isEmbeddedNvimTerminal,
  notificationTypeLabel,
  parseClientLine,
  parseTmuxClientInfo,
  parseArgs,
  projectName,
  sanitizeOscField,
  selectClientTargets,
  selectNotificationTransport,
  selectTmuxClientInfo,
  supportsOsc777,
  supportsOsc777ViaTmuxClientInfo,
  wrapForTmux,
  type ClaudeHookInput,
  type CodexNotifyPayload,
  type NotificationTransport,
  type TmuxClientInfo,
} from "./agent-notify.ts";

// ---------------------------------------------------------------------------
// projectName
// ---------------------------------------------------------------------------

describe("projectName", () => {
  test("extracts last directory segment from cwd", () => {
    expect(projectName("/home/user/myproject")).toBe("myproject");
  });

  test("handles trailing slashes", () => {
    expect(projectName("/home/user/myproject/")).toBe("myproject");
  });

  test("returns empty string for undefined", () => {
    expect(projectName(undefined)).toBe("");
  });

  test("returns empty string for empty string", () => {
    expect(projectName("")).toBe("");
  });

  test("handles root path", () => {
    expect(projectName("/")).toBe("");
  });

  test("handles Windows paths", () => {
    expect(projectName("C:\\Users\\user\\myproject")).toBe("myproject");
    expect(projectName("C:\\Users\\user\\myproject\\")).toBe("myproject");
  });
});

// ---------------------------------------------------------------------------
// notificationTypeLabel
// ---------------------------------------------------------------------------

describe("notificationTypeLabel", () => {
  const cases: [string | undefined, string][] = [
    ["permission_prompt", "Permission required"],
    ["idle_prompt", "Awaiting input"],
    ["auth_success", "Auth succeeded"],
    ["elicitation_dialog", "Question"],
    ["unknown", "Notification"],
    [undefined, "Notification"],
  ];

  for (const [input, expected] of cases) {
    test(`maps ${input ?? "undefined"} → ${expected}`, () => {
      expect(notificationTypeLabel(input)).toBe(expected);
    });
  }
});

// ---------------------------------------------------------------------------
// formatClaudeHook
// ---------------------------------------------------------------------------

describe("formatClaudeHook", () => {
  const baseInput: ClaudeHookInput = {
    session_id: "test-session",
    hook_event_name: "Notification",
  };

  test("formats Notification with permission_prompt", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      notification_type: "permission_prompt",
      message: "Claude needs your permission to use Bash",
      cwd: "/home/user/myproject",
    };

    const result = formatClaudeHook(input);

    expect(result.title).toBe("Claude Code \u2014 myproject");
    expect(result.body).toBe("Permission required: Claude needs your permission to use Bash");
    expect(result.source).toBe("claude");
    expect(result.event).toBe("permission_prompt");
    expect(result.cwd).toBe("/home/user/myproject");
  });

  test("formats Notification with idle_prompt", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      notification_type: "idle_prompt",
      message: "Waiting for input",
    };

    const result = formatClaudeHook(input);

    expect(result.body).toBe("Awaiting input: Waiting for input");
  });

  test("formats Notification without cwd (no project label)", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      message: "Something happened",
    };

    const result = formatClaudeHook(input);

    expect(result.title).toBe("Claude Code");
  });

  test("formats Notification with unknown type", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      notification_type: "something_new",
      message: "New event",
    };

    const result = formatClaudeHook(input);

    expect(result.body).toBe("Notification: New event");
  });

  test("formats Stop event", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "Stop",
      cwd: "/home/user/myproject",
    };

    const result = formatClaudeHook(input);

    expect(result.title).toBe("Claude Code \u2014 myproject");
    expect(result.body).toBe("Task complete");
    expect(result.event).toBe("stop");
  });

  test("formats SubagentStop event", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "SubagentStop",
      cwd: "/home/user/myproject",
    };

    const result = formatClaudeHook(input);

    expect(result.body).toBe("Subagent finished");
    expect(result.event).toBe("subagent_stop");
  });

  test("formats StopFailure event", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "StopFailure",
      error: "server_error",
      cwd: "/home/user/myproject",
    };

    const result = formatClaudeHook(input);

    expect(result.title).toBe("Claude Code \u2014 myproject");
    expect(result.body).toBe("Task failed: server_error");
    expect(result.event).toBe("stop_failure");
  });

  test("formats unknown event", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "CustomEvent",
      message: "Custom message",
    };

    const result = formatClaudeHook(input);

    expect(result.body).toBe("Custom message");
    expect(result.event).toBe("CustomEvent");
  });

  test("formats unknown event without message (falls back to event name)", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "CustomEvent",
    };

    const result = formatClaudeHook(input);

    expect(result.body).toBe("CustomEvent");
  });

  test("formats PermissionRequest with tool_name and command", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "PermissionRequest",
      tool_name: "Bash",
      tool_input: { command: "rm -rf node_modules" },
      cwd: "/home/user/myproject",
    };

    const result = formatClaudeHook(input);

    expect(result.title).toBe("Claude Code \u2014 myproject");
    expect(result.body).toBe("Bash: rm -rf node_modules");
    expect(result.event).toBe("permission_request");
  });

  test("formats PermissionRequest without tool_input", () => {
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "PermissionRequest",
      tool_name: "Edit",
    };

    const result = formatClaudeHook(input);

    expect(result.body).toBe("Permission: Edit");
  });

  test("formats PermissionRequest with long command (truncated)", () => {
    const longCmd = "a".repeat(150);
    const input: ClaudeHookInput = {
      ...baseInput,
      hook_event_name: "PermissionRequest",
      tool_name: "Bash",
      tool_input: { command: longCmd },
    };

    const result = formatClaudeHook(input);

    expect(result.body.length).toBeLessThan(100);
    expect(result.body).toContain("Bash:");
    expect(result.body).toContain("...");
  });
});

// ---------------------------------------------------------------------------
// buildOsc777
// ---------------------------------------------------------------------------

describe("buildOsc777", () => {
  test("produces correct OSC 777 sequence", () => {
    const result = buildOsc777("Title", "Body text");

    expect(result).toBe("\x1b]777;notify;Title;Body text\x1b\\");
  });

  test("handles empty body", () => {
    const result = buildOsc777("Title", "");

    expect(result).toBe("\x1b]777;notify;Title;\x1b\\");
  });

  test("sanitizes control characters from title and body", () => {
    const result = buildOsc777("Title\x07\x1b", "Body\x07\x1btext");

    expect(result).toBe("\x1b]777;notify;Title;Bodytext\x1b\\");
  });

  test("replaces semicolons with colons", () => {
    const result = buildOsc777("Title;extra", "Body;text");

    expect(result).toBe("\x1b]777;notify;Title:extra;Body:text\x1b\\");
  });
});

// ---------------------------------------------------------------------------
// sanitizeOscField
// ---------------------------------------------------------------------------

describe("sanitizeOscField", () => {
  test("strips BEL character", () => {
    expect(sanitizeOscField("hello\x07world")).toBe("helloworld");
  });

  test("strips ESC character", () => {
    expect(sanitizeOscField("hello\x1bworld")).toBe("helloworld");
  });

  test("strips newlines and tabs", () => {
    expect(sanitizeOscField("hello\n\tworld")).toBe("helloworld");
  });

  test("strips C1 control characters", () => {
    expect(sanitizeOscField("hello\u009bworld")).toBe("helloworld");
  });

  test("replaces semicolons with colons", () => {
    expect(sanitizeOscField("a;b;c")).toBe("a:b:c");
  });

  test("returns unchanged safe string", () => {
    expect(sanitizeOscField("Hello World")).toBe("Hello World");
  });
});

// ---------------------------------------------------------------------------
// wrapForTmux
// ---------------------------------------------------------------------------

describe("wrapForTmux", () => {
  test("returns sequence unchanged when not in tmux", () => {
    const sequence = "\x1b]777;notify;Title;Body\x1b\\";

    expect(wrapForTmux(sequence, false)).toBe(sequence);
  });

  test("wraps sequence in DCS passthrough when in tmux", () => {
    const sequence = "\x1b]777;notify;Title;Body\x1b\\";
    const result = wrapForTmux(sequence, true);

    expect(result).toBe("\x1bPtmux;\x1b\x1b]777;notify;Title;Body\x1b\x1b\\\x1b\\");
  });

  test("doubles all ESC characters in the wrapped sequence", () => {
    const sequence = "\x1b]777;notify;\x1bTitle;Body\x1b\\";
    const result = wrapForTmux(sequence, true);

    expect(result).toBe("\x1bPtmux;\x1b\x1b]777;notify;\x1b\x1bTitle;Body\x1b\x1b\\\x1b\\");
  });

  test("handles empty sequence", () => {
    expect(wrapForTmux("", false)).toBe("");
    expect(wrapForTmux("", true)).toBe("\x1bPtmux;\x1b\\");
  });
});

// ---------------------------------------------------------------------------
// parseTmuxClientInfo
// ---------------------------------------------------------------------------

describe("parseTmuxClientInfo", () => {
  test("parses client termname and termtype", () => {
    expect(parseTmuxClientInfo("wezterm|WezTerm 20240203")).toEqual({
      termname: "wezterm",
      termtype: "WezTerm 20240203",
    });
  });

  test("returns null for empty line", () => {
    expect(parseTmuxClientInfo("")).toBeNull();
    expect(parseTmuxClientInfo("|")).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// isEmbeddedNvimTerminal
// ---------------------------------------------------------------------------

describe("isEmbeddedNvimTerminal", () => {
  test("detects Neovim terminal jobs via NVIM", () => {
    expect(isEmbeddedNvimTerminal({ NVIM: "/tmp/nvim.sock" })).toBe(true);
  });

  test("returns false outside Neovim", () => {
    expect(isEmbeddedNvimTerminal({})).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// selectTmuxClientInfo
// ---------------------------------------------------------------------------

describe("selectTmuxClientInfo", () => {
  test("returns first client when all clients support WezTerm OSC", () => {
    const clients: TmuxClientInfo[] = [
      { termname: "xterm-256color", termtype: "WezTerm 20240203" },
      { termname: "wezterm", termtype: "xterm-256color" },
    ];

    expect(selectTmuxClientInfo(clients)).toEqual({
      termname: "xterm-256color",
      termtype: "WezTerm 20240203",
    });
  });

  test("returns null when any attached client is not WezTerm", () => {
    const clients: TmuxClientInfo[] = [
      { termname: "xterm-256color", termtype: "WezTerm 20240203" },
      { termname: "xterm-256color", termtype: "tmux-256color" },
    ];

    expect(selectTmuxClientInfo(clients)).toBeNull();
  });

  test("returns null for empty client list", () => {
    expect(selectTmuxClientInfo([])).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// selectNotificationTransport
// ---------------------------------------------------------------------------

describe("selectNotificationTransport", () => {
  test("prefers tmux pane tty for Neovim terminal inside tmux", () => {
    const transport: NotificationTransport = selectNotificationTransport(
      { NVIM: "/tmp/nvim.sock", TMUX_PANE: "%1", TMUX: "/tmp/tmux", TERM_PROGRAM: "tmux" },
      { termname: "xterm-256color", termtype: "WezTerm 20240203" },
    );

    expect(transport).toEqual({
      preferTmuxPaneTty: true,
      allowOsc777: true,
    });
  });

  test("disables OSC 777 for Neovim terminal without tmux bypass", () => {
    const transport: NotificationTransport = selectNotificationTransport(
      { NVIM: "/tmp/nvim.sock", TERM_PROGRAM: "WezTerm" },
      null,
    );

    expect(transport).toEqual({
      preferTmuxPaneTty: false,
      allowOsc777: false,
    });
  });
});

// ---------------------------------------------------------------------------
// supportsOsc777ViaTmuxClientInfo
// ---------------------------------------------------------------------------

describe("supportsOsc777ViaTmuxClientInfo", () => {
  test("detects wezterm termname", () => {
    const info: TmuxClientInfo = { termname: "wezterm", termtype: "xterm-256color" };
    expect(supportsOsc777ViaTmuxClientInfo(info)).toBe(true);
  });

  test("detects wezterm client termtype", () => {
    const info: TmuxClientInfo = { termname: "xterm-256color", termtype: "WezTerm 20240203" };
    expect(supportsOsc777ViaTmuxClientInfo(info)).toBe(true);
  });

  test("returns false for non-wezterm clients", () => {
    const info: TmuxClientInfo = { termname: "xterm-256color", termtype: "tmux-256color" };
    expect(supportsOsc777ViaTmuxClientInfo(info)).toBe(false);
    expect(supportsOsc777ViaTmuxClientInfo(null)).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// supportsOsc777
// ---------------------------------------------------------------------------

describe("supportsOsc777", () => {
  test("detects WezTerm via TERM_PROGRAM", () => {
    expect(supportsOsc777({ TERM_PROGRAM: "WezTerm" })).toBe(true);
  });

  test("detects WezTerm via WEZTERM_PANE", () => {
    expect(supportsOsc777({ WEZTERM_PANE: "1" })).toBe(true);
  });

  test("detects WezTerm via tmux client info when pane env is tmux", () => {
    expect(
      supportsOsc777(
        { TMUX: "/tmp/tmux", TERM_PROGRAM: "tmux" },
        { termname: "xterm-256color", termtype: "WezTerm 20240203" },
      ),
    ).toBe(true);
  });

  test("does not trust TERM_PROGRAM inside tmux without WezTerm client metadata", () => {
    expect(supportsOsc777({ TMUX: "/tmp/tmux", TERM_PROGRAM: "WezTerm" }, null)).toBe(false);
  });

  test("returns false inside Neovim terminal without tmux bypass", () => {
    expect(supportsOsc777({ NVIM: "/tmp/nvim.sock", TERM_PROGRAM: "WezTerm" })).toBe(false);
  });

  test("returns false for other terminals", () => {
    expect(supportsOsc777({ TERM_PROGRAM: "Apple_Terminal" })).toBe(false);
    expect(supportsOsc777({})).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// buildTerminalNotification
// ---------------------------------------------------------------------------

describe("buildTerminalNotification", () => {
  test("returns bell only for unknown terminals", () => {
    expect(buildTerminalNotification("Title", "Body", {})).toBe("\x07");
  });

  test("returns bell plus OSC 777 for WezTerm", () => {
    expect(buildTerminalNotification("Title", "Body", { TERM_PROGRAM: "WezTerm" })).toBe(
      "\x07\x1b]777;notify;Title;Body\x1b\\",
    );
  });

  test("returns bell only in tmux without trusted WezTerm client metadata", () => {
    expect(buildTerminalNotification("Title", "Body", { TERM_PROGRAM: "WezTerm", TMUX: "/tmp/tmux" })).toBe("\x07");
  });

  test("wraps OSC 777 when tmux client info identifies WezTerm", () => {
    expect(
      buildTerminalNotification(
        "Title",
        "Body",
        { TERM_PROGRAM: "tmux", TMUX: "/tmp/tmux" },
        { termname: "xterm-256color", termtype: "WezTerm 20240203" },
      ),
    ).toBe("\x07\x1bPtmux;\x1b\x1b]777;notify;Title;Body\x1b\x1b\\\x1b\\");
  });

  test("returns bell only inside Neovim terminal without tmux bypass", () => {
    expect(buildTerminalNotification("Title", "Body", { NVIM: "/tmp/nvim.sock", TERM_PROGRAM: "WezTerm" })).toBe(
      "\x07",
    );
  });
});

// ---------------------------------------------------------------------------
// parseArgs
// ---------------------------------------------------------------------------

describe("parseArgs", () => {
  test("parses --stdin flag", () => {
    const result = parseArgs(["--stdin"]);

    expect(result.stdin).toBe(true);
    expect(result.title).toBeUndefined();
    expect(result.body).toBeUndefined();
  });

  test("parses --title and --body flags", () => {
    const result = parseArgs(["--title", "My Title", "--body", "My Body"]);

    expect(result.title).toBe("My Title");
    expect(result.body).toBe("My Body");
    expect(result.stdin).toBe(false);
  });

  test("parses short -t and -b flags", () => {
    const result = parseArgs(["-t", "Title", "-b", "Body"]);

    expect(result.title).toBe("Title");
    expect(result.body).toBe("Body");
  });

  test("parses positional args as title and body", () => {
    const result = parseArgs(["Title", "Body"]);

    expect(result.title).toBe("Title");
    expect(result.body).toBe("Body");
  });

  test("parses single positional as title only", () => {
    const result = parseArgs(["Title"]);

    expect(result.title).toBe("Title");
    expect(result.body).toBeUndefined();
  });

  test("returns empty defaults for no args", () => {
    const result = parseArgs([]);

    expect(result.stdin).toBe(false);
    expect(result.title).toBeUndefined();
    expect(result.body).toBeUndefined();
  });

  test("flag values take precedence over positional", () => {
    const result = parseArgs(["--title", "Flag", "Positional"]);

    expect(result.title).toBe("Flag");
    expect(result.body).toBeUndefined();
  });

  test("uses the last repeated string option", () => {
    const result = parseArgs(["--title", "First", "--title", "Second", "--body", "One", "--body", "Two"]);

    expect(result.title).toBe("Second");
    expect(result.body).toBe("Two");
  });

  test("defaults format to auto", () => {
    const result = parseArgs(["Title"]);

    expect(result.format).toBe("auto");
  });

  test("parses --format codex", () => {
    const result = parseArgs(["--format", "codex"]);

    expect(result.format).toBe("codex");
  });

  test("parses --format claude", () => {
    const result = parseArgs(["--format", "claude"]);

    expect(result.format).toBe("claude");
  });

  test("falls back to auto for invalid format", () => {
    const result = parseArgs(["--format", "invalid"]);

    expect(result.format).toBe("auto");
  });

  test("codex mode keeps positionals raw without title/body mapping", () => {
    const jsonPayload = '{"type":"agent-turn-complete","thread-id":"t1"}';
    const result = parseArgs(["--format", "codex", jsonPayload]);

    expect(result.format).toBe("codex");
    expect(result.positionals[0]).toBe(jsonPayload);
    expect(result.title).toBeUndefined();
  });

  test("auto mode maps positionals to title/body as before", () => {
    const result = parseArgs(["MyTitle", "MyBody"]);

    expect(result.format).toBe("auto");
    expect(result.title).toBe("MyTitle");
    expect(result.body).toBe("MyBody");
  });

  test("exposes positionals in auto mode", () => {
    const result = parseArgs(["Title", "Body"]);

    expect(result.positionals).toEqual(["Title", "Body"]);
  });
});

// ---------------------------------------------------------------------------
// isCodexNotifyPayload
// ---------------------------------------------------------------------------

describe("isCodexNotifyPayload", () => {
  test("recognizes payload with thread-id", () => {
    expect(isCodexNotifyPayload({ type: "agent-turn-complete", "thread-id": "t1" })).toBe(true);
  });

  test("recognizes payload with turn-id", () => {
    expect(isCodexNotifyPayload({ type: "agent-turn-complete", "turn-id": "turn1" })).toBe(true);
  });

  test("recognizes payload with both", () => {
    expect(
      isCodexNotifyPayload({ type: "agent-turn-complete", "thread-id": "t1", "turn-id": "turn1" }),
    ).toBe(true);
  });

  test("rejects payload without codex-specific fields", () => {
    expect(isCodexNotifyPayload({ type: "agent-turn-complete" })).toBe(false);
  });

  test("rejects null", () => {
    expect(isCodexNotifyPayload(null)).toBe(false);
  });

  test("rejects non-object", () => {
    expect(isCodexNotifyPayload("string")).toBe(false);
    expect(isCodexNotifyPayload(42)).toBe(false);
  });

  test("rejects Claude hook input (has hook_event_name, not codex fields)", () => {
    expect(
      isCodexNotifyPayload({ type: "Notification", hook_event_name: "Stop", session_id: "s1" }),
    ).toBe(false);
  });

  test("rejects object with non-string type", () => {
    expect(isCodexNotifyPayload({ type: 42, "thread-id": "t1" })).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// formatCodexEvent
// ---------------------------------------------------------------------------

describe("formatCodexEvent", () => {
  test("formats agent-turn-complete with cwd", () => {
    const payload: CodexNotifyPayload = {
      type: "agent-turn-complete",
      "thread-id": "t1",
      "turn-id": "turn1",
      cwd: "/home/user/myproject",
    };

    const result = formatCodexEvent(payload);

    expect(result.title).toBe("Codex \u2014 myproject");
    expect(result.body).toBe("Task complete");
    expect(result.source).toBe("codex");
    expect(result.event).toBe("agent-turn-complete");
    expect(result.cwd).toBe("/home/user/myproject");
  });

  test("formats agent-turn-complete without cwd", () => {
    const payload: CodexNotifyPayload = {
      type: "agent-turn-complete",
      "thread-id": "t1",
    };

    const result = formatCodexEvent(payload);

    expect(result.title).toBe("Codex");
    expect(result.body).toBe("Task complete");
  });

  test("formats unknown type with last-assistant-message", () => {
    const payload: CodexNotifyPayload = {
      type: "custom-event",
      "thread-id": "t1",
      cwd: "/home/user/myproject",
      "last-assistant-message": "Done working",
    };

    const result = formatCodexEvent(payload);

    expect(result.title).toBe("Codex — myproject");
    expect(result.body).toBe("Done working");
    expect(result.event).toBe("custom-event");
  });

  test("formats unknown type without message (falls back to type)", () => {
    const payload: CodexNotifyPayload = {
      type: "custom-event",
      "turn-id": "turn1",
    };

    const result = formatCodexEvent(payload);

    expect(result.body).toBe("custom-event");
  });
});

// ---------------------------------------------------------------------------
// parseClientLine
// ---------------------------------------------------------------------------

describe("parseClientLine", () => {
  test("parses valid line with tty, termname, termtype", () => {
    expect(parseClientLine("/dev/pts/3|wezterm|WezTerm 20240203")).toEqual({
      tty: "/dev/pts/3",
      termname: "wezterm",
      termtype: "WezTerm 20240203",
      flags: [],
    });
  });

  test("parses non-WezTerm client", () => {
    expect(parseClientLine("/dev/pts/5|xterm-256color|tmux-256color")).toEqual({
      tty: "/dev/pts/5",
      termname: "xterm-256color",
      termtype: "tmux-256color",
      flags: [],
    });
  });

  test("parses client flags when present", () => {
    expect(parseClientLine("/dev/pts/3|wezterm|WezTerm 20240203|attached,focused,UTF-8")).toEqual({
      tty: "/dev/pts/3",
      termname: "wezterm",
      termtype: "WezTerm 20240203",
      flags: ["attached", "focused", "UTF-8"],
    });
  });

  test("returns null for empty line", () => {
    expect(parseClientLine("")).toBeNull();
  });

  test("returns null for separators only", () => {
    expect(parseClientLine("||")).toBeNull();
  });

  test("trims whitespace before parsing", () => {
    expect(parseClientLine("  /dev/pts/1|wezterm|WezTerm 1  ")).toEqual({
      tty: "/dev/pts/1",
      termname: "wezterm",
      termtype: "WezTerm 1",
      flags: [],
    });
  });

  test("returns null when tty field is empty", () => {
    expect(parseClientLine("|wezterm|WezTerm 20240203")).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// selectClientTargets
// ---------------------------------------------------------------------------

describe("selectClientTargets", () => {
  test("prefers focused clients when present", () => {
    const clients = [
      { tty: "/dev/pts/1", termname: "wezterm", termtype: "WezTerm 1", flags: ["attached"] },
      { tty: "/dev/pts/2", termname: "wezterm", termtype: "WezTerm 1", flags: ["attached", "focused"] },
    ];

    expect(selectClientTargets(clients)).toEqual([
      { tty: "/dev/pts/2", termname: "wezterm", termtype: "WezTerm 1", flags: ["attached", "focused"] },
    ]);
  });

  test("returns all clients when none are focused", () => {
    const clients = [
      { tty: "/dev/pts/1", termname: "wezterm", termtype: "WezTerm 1", flags: ["attached"] },
      { tty: "/dev/pts/2", termname: "xterm-256color", termtype: "tmux-256color", flags: ["attached"] },
    ];

    expect(selectClientTargets(clients)).toEqual(clients);
  });

  test("supports multiple focused clients", () => {
    const clients = [
      { tty: "/dev/pts/1", termname: "wezterm", termtype: "WezTerm 1", flags: ["attached", "focused"] },
      { tty: "/dev/pts/2", termname: "wezterm", termtype: "WezTerm 2", flags: ["attached", "focused"] },
      { tty: "/dev/pts/3", termname: "wezterm", termtype: "WezTerm 3", flags: ["attached"] },
    ];

    expect(selectClientTargets(clients)).toEqual([
      { tty: "/dev/pts/1", termname: "wezterm", termtype: "WezTerm 1", flags: ["attached", "focused"] },
      { tty: "/dev/pts/2", termname: "wezterm", termtype: "WezTerm 2", flags: ["attached", "focused"] },
    ]);
  });
});

// ---------------------------------------------------------------------------
// clientNotificationSequence
// ---------------------------------------------------------------------------

describe("clientNotificationSequence", () => {
  test("WezTerm client gets BEL + raw OSC 777", () => {
    const seq = clientNotificationSequence("Title", "Body", {
      termname: "wezterm",
      termtype: "WezTerm 20240203",
    });

    expect(seq).toBe("\x07\x1b]777;notify;Title;Body\x1b\\");
  });

  test("WezTerm via termtype gets BEL + raw OSC 777", () => {
    const seq = clientNotificationSequence("Title", "Body", {
      termname: "xterm-256color",
      termtype: "WezTerm 20240203",
    });

    expect(seq).toBe("\x07\x1b]777;notify;Title;Body\x1b\\");
  });

  test("non-WezTerm client gets BEL only", () => {
    const seq = clientNotificationSequence("Title", "Body", {
      termname: "xterm-256color",
      termtype: "tmux-256color",
    });

    expect(seq).toBe("\x07");
  });

  test("OSC 777 is NOT DCS-wrapped (bypasses tmux)", () => {
    const seq = clientNotificationSequence("Title", "Body", {
      termname: "wezterm",
      termtype: "WezTerm 20240203",
    });

    // Must NOT contain DCS passthrough prefix
    expect(seq).not.toContain("\x1bPtmux;");
  });

  test("sanitizes title and body in OSC 777", () => {
    const seq = clientNotificationSequence("Title;bad", "Body\x07ctrl", {
      termname: "wezterm",
      termtype: "WezTerm 20240203",
    });

    expect(seq).toContain("Title:bad");
    expect(seq).not.toContain("Title;bad");
    expect(seq).not.toContain("\x07ctrl");
  });
});
