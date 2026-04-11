import { describe, expect, test } from "bun:test";

import {
  buildOsc777,
  formatClaudeHook,
  formatCodexNotify,
  notificationTypeLabel,
  parseArgs,
  projectName,
  sanitizeOscField,
  wrapForTmux,
  type ClaudeHookInput,
  type CodexNotifyInput,
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
});

// ---------------------------------------------------------------------------
// notificationTypeLabel
// ---------------------------------------------------------------------------

describe("notificationTypeLabel", () => {
  test("maps permission_prompt", () => {
    expect(notificationTypeLabel("permission_prompt")).toBe("Permission required");
  });

  test("maps idle_prompt", () => {
    expect(notificationTypeLabel("idle_prompt")).toBe("Awaiting input");
  });

  test("maps auth_success", () => {
    expect(notificationTypeLabel("auth_success")).toBe("Auth succeeded");
  });

  test("maps elicitation_dialog", () => {
    expect(notificationTypeLabel("elicitation_dialog")).toBe("Question");
  });

  test("returns Notification for unknown type", () => {
    expect(notificationTypeLabel("unknown")).toBe("Notification");
  });

  test("returns Notification for undefined", () => {
    expect(notificationTypeLabel(undefined)).toBe("Notification");
  });
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
});

// ---------------------------------------------------------------------------
// formatCodexNotify
// ---------------------------------------------------------------------------

describe("formatCodexNotify", () => {
  test("formats agent-turn-complete with message", () => {
    const input: CodexNotifyInput = {
      type: "agent-turn-complete",
      "thread-id": "t1",
      "turn-id": "turn1",
      cwd: "/home/user/myproject",
      "last-assistant-message": "I fixed the bug in auth.ts",
      client: "codex-tui",
    };

    const result = formatCodexNotify(input);

    expect(result.title).toBe("Codex \u2014 myproject");
    expect(result.body).toBe("I fixed the bug in auth.ts");
    expect(result.source).toBe("codex");
    expect(result.event).toBe("agent-turn-complete");
  });

  test("truncates messages longer than 120 characters", () => {
    const longMessage = "a".repeat(150);
    const input: CodexNotifyInput = {
      type: "agent-turn-complete",
      "last-assistant-message": longMessage,
    };

    const result = formatCodexNotify(input);

    expect(result.body.length).toBe(120);
    expect(result.body.endsWith("...")).toBe(true);
    expect(result.body).toBe("a".repeat(117) + "...");
  });

  test("uses fallback body when no message", () => {
    const input: CodexNotifyInput = {
      type: "agent-turn-complete",
    };

    const result = formatCodexNotify(input);

    expect(result.body).toBe("Turn complete");
  });

  test("uses fallback event when no type", () => {
    const input: CodexNotifyInput = { type: "" };

    const result = formatCodexNotify(input);

    expect(result.event).toBe("agent-turn-complete");
  });

  test("omits project label without cwd", () => {
    const input: CodexNotifyInput = {
      type: "agent-turn-complete",
    };

    const result = formatCodexNotify(input);

    expect(result.title).toBe("Codex");
  });
});

// ---------------------------------------------------------------------------
// buildOsc777
// ---------------------------------------------------------------------------

describe("buildOsc777", () => {
  test("produces correct OSC 777 sequence", () => {
    const result = buildOsc777("Title", "Body text");

    expect(result).toBe("\x1b]777;notify;Title;Body text\x07");
  });

  test("handles empty body", () => {
    const result = buildOsc777("Title", "");

    expect(result).toBe("\x1b]777;notify;Title;\x07");
  });

  test("sanitizes control characters from title and body", () => {
    const result = buildOsc777("Title\x07\x1b", "Body\x07\x1btext");

    expect(result).toBe("\x1b]777;notify;Title;Bodytext\x07");
  });

  test("replaces semicolons with colons", () => {
    const result = buildOsc777("Title;extra", "Body;text");

    expect(result).toBe("\x1b]777;notify;Title:extra;Body:text\x07");
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
    const sequence = "\x1b]777;notify;Title;Body\x07";

    expect(wrapForTmux(sequence, false)).toBe(sequence);
  });

  test("wraps sequence in DCS passthrough when in tmux", () => {
    const sequence = "\x1b]777;notify;Title;Body\x07";
    const result = wrapForTmux(sequence, true);

    // DCS format: \ePtmux;\e + (content with every \e doubled) + \e\\
    // Original has 1 ESC before ]777 → doubled to 2 ESCs, plus 1 from prefix = 3 ESCs
    expect(result).toBe("\x1bPtmux;\x1b\x1b\x1b]777;notify;Title;Body\x07\x1b\\");
  });

  test("doubles all ESC characters in the wrapped sequence", () => {
    const sequence = "\x1b]777;notify;\x1bTitle;Body\x07";
    const result = wrapForTmux(sequence, true);

    // Original has 2 ESCs → each doubled → 4 ESCs in content + 1 from prefix
    expect(result).toBe("\x1bPtmux;\x1b\x1b\x1b]777;notify;\x1b\x1bTitle;Body\x07\x1b\\");
  });

  test("handles empty sequence", () => {
    expect(wrapForTmux("", false)).toBe("");
    expect(wrapForTmux("", true)).toBe("\x1bPtmux;\x1b\x1b\\");
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

  test("parses --codex-arg with JSON string", () => {
    const json = '{"type":"agent-turn-complete"}';
    const result = parseArgs(["--codex-arg", json]);

    expect(result.codexArg).toBe(json);
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
    expect(result.codexArg).toBeUndefined();
  });

  test("flag values take precedence over positional", () => {
    const result = parseArgs(["--title", "Flag", "Positional"]);

    expect(result.title).toBe("Flag");
    expect(result.body).toBeUndefined();
  });
});
