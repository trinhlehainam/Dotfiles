import { describe, expect, test } from "bun:test";

import {
  buildNonLiveCommandArgs,
  handleSpawnResult,
  ParseCliError,
  parseCliArgs,
  runWorktreeCommand,
} from "./worktree-dev.ts";
import type { ChezmoiRuntime, CommandResult } from "./worktree-runtime.ts";

test.each([
  ["context", ["execute-template", "{{ .chezmoi.workingTree }}|{{ .chezmoi.sourceDir }}"]],
  ["diff", ["diff"]],
  ["dry-run", ["apply", "--dry-run", "--verbose"]],
  ["apply-temp", ["apply", "--verbose"]],
] as const)("builds %s arguments without --init", (command, expected) => {
  const args = buildNonLiveCommandArgs(command);
  expect(args).toEqual([...expected]);
  expect(args).not.toContain("--init");
});

test("reconciles before running chezmoi and always removes the runtime", async () => {
  const calls: string[] = [];
  const runtime: ChezmoiRuntime = {
    cacheDir: "/runtime/cache",
    configFile: "/runtime/config.toml",
    destinationDir: "/destination",
    persistentStateFile: "/runtime/state.boltdb",
    sourceDir: "/repo/home",
    worktreeRoot: "/repo",
  };
  const commandResult: CommandResult = {
    signal: null,
    status: 0,
    stderr: Buffer.alloc(0),
    stdout: Buffer.alloc(0),
  };

  const result = await runWorktreeCommand("diff", "/repo", "/destination", {
    reconcile: async () => {
      calls.push("reconcile");
      return { tools: [] };
    },
    createRuntime: async () => {
      calls.push("create-runtime");
      return runtime;
    },
    run: (_runtime, args) => {
      calls.push(`run:${args.join(",")}`);
      return commandResult;
    },
    removeRuntime: async () => {
      calls.push("remove-runtime");
    },
  });

  expect(result).toBe(commandResult);
  expect(calls).toEqual(["reconcile", "create-runtime", "run:diff", "remove-runtime"]);
});

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
