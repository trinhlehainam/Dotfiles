import { describe, expect, test } from "bun:test";

import { parseCliArgs } from "./worktree-dev.ts";

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
});
