import { describe, expect, test } from "bun:test";

import { handleSpawnResult, ParseCliError, parseCliArgs } from "./worktree-dev.ts";

describe("parseCliArgs", () => {
  test("parses command positional", () => {
    expect(parseCliArgs(["context"])).toEqual({
      command: "context",
      help: false,
    });
  });

  test("parses help flag", () => {
    expect(parseCliArgs(["--help"])).toEqual({
      command: undefined,
      help: true,
    });
  });

  test("parses short help flag with command", () => {
    expect(parseCliArgs(["-h", "diff"])).toEqual({
      command: "diff",
      help: true,
    });
  });

  test("throws ParseCliError for unknown commands", () => {
    try {
      parseCliArgs(["nope"]);
      throw new Error("expected parseCliArgs to throw");
    } catch (error) {
      expect(error).toBeInstanceOf(ParseCliError);
      expect((error as Error).message).toContain("unknown command: nope");
      expect((error as Error).message).toContain("[--help|-h]");
    }
  });

  test("throws ParseCliError for too many positionals", () => {
    try {
      parseCliArgs(["context", "diff"]);
      throw new Error("expected parseCliArgs to throw");
    } catch (error) {
      expect(error).toBeInstanceOf(ParseCliError);
      expect((error as Error).message).toContain("expected exactly one command");
    }
  });

  test("re-raises child signals instead of converting them to exit code 1", () => {
    const calls: string[] = [];

    handleSpawnResult(
      { signal: "SIGTERM", status: null },
      {
        fail: (message) => calls.push(`fail:${message}`),
        exit: (code) => calls.push(`exit:${code}`),
        raiseSignal: (signal) => calls.push(`signal:${signal}`),
      },
    );

    expect(calls).toEqual(["signal:SIGTERM"]);
  });
});
