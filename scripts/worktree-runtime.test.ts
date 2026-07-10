import { describe, expect, test } from "bun:test";

import {
  buildChezmoiArgs,
  createEphemeralRuntime,
  removeEphemeralRuntime,
  requireSuccess,
  runChezmoi,
  runCommand,
  type ChezmoiRuntime,
  type CommandResult,
  type CommandRunner,
} from "./worktree-runtime.ts";

const runtime: ChezmoiRuntime = {
  cacheDir: "/session/cache",
  configFile: "/session/config.toml",
  destinationDir: "/home/tester",
  persistentStateFile: "/session/state.boltdb",
  sourceDir: "/repo/home",
  worktreeRoot: "/repo",
};

describe("buildChezmoiArgs", () => {
  test("uses explicit long-form isolation flags before command arguments", () => {
    expect(buildChezmoiArgs(runtime, ["status", "--path-style", "absolute"])).toEqual([
      "--source",
      "/repo/home",
      "--working-tree",
      "/repo",
      "--config",
      "/session/config.toml",
      "--cache",
      "/session/cache",
      "--persistent-state",
      "/session/state.boltdb",
      "--destination",
      "/home/tester",
      "status",
      "--path-style",
      "absolute",
    ]);
  });

  test("never adds --init", () => {
    expect(buildChezmoiArgs(runtime, ["apply"])).not.toContain("--init");
  });
});

import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

test("creates and removes a hookless isolated runtime", async () => {
  const parent = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-runtime-test-"));
  const runtime = await createEphemeralRuntime({
    destinationDir: path.join(parent, "home"),
    sourceDir: "/repo/home",
    tempParent: parent,
    worktreeRoot: "/repo",
  });

  expect(await fs.readFile(runtime.configFile, "utf8")).toBe("");
  expect(runtime.cacheDir.startsWith(parent)).toBe(true);

  await removeEphemeralRuntime(runtime);
  await expect(fs.stat(path.dirname(runtime.configFile))).rejects.toMatchObject({ code: "ENOENT" });
});

function commandResult(overrides: Partial<CommandResult> = {}): CommandResult {
  return {
    signal: null,
    status: 0,
    stderr: Buffer.alloc(0),
    stdout: Buffer.alloc(0),
    ...overrides,
  };
}

describe("runCommand", () => {
  test("forwards the command and arguments to the injected runner", () => {
    const expectedResult = commandResult({ stdout: Buffer.from("ok") });
    let invocation: { args: string[]; command: string } | undefined;
    const runner: CommandRunner = (command, args) => {
      invocation = { args, command };
      return expectedResult;
    };

    const result = runCommand("git", ["status", "--short"], runner);

    expect(invocation).toEqual({ command: "git", args: ["status", "--short"] });
    expect(result).toBe(expectedResult);
  });
});

describe("runChezmoi", () => {
  test("forwards chezmoi with exact isolated arguments to the injected runner", () => {
    let invocation: { args: string[]; command: string } | undefined;
    const runner: CommandRunner = (command, args) => {
      invocation = { args, command };
      return commandResult();
    };

    runChezmoi(runtime, ["apply", "--dry-run"], runner);

    expect(invocation).toEqual({
      command: "chezmoi",
      args: [
        "--source",
        "/repo/home",
        "--working-tree",
        "/repo",
        "--config",
        "/session/config.toml",
        "--cache",
        "/session/cache",
        "--persistent-state",
        "/session/state.boltdb",
        "--destination",
        "/home/tester",
        "apply",
        "--dry-run",
      ],
    });
  });
});

describe("requireSuccess", () => {
  test("throws the spawn error with context", () => {
    const result = commandResult({ error: new Error("spawn failed"), status: null });

    expect(() => requireSuccess(result, "worktree status")).toThrow(
      "worktree status: spawn failed",
    );
  });

  test("throws when the command terminates from a signal", () => {
    const result = commandResult({ signal: "SIGTERM", status: null });

    expect(() => requireSuccess(result)).toThrow("chezmoi: terminated by SIGTERM");
  });

  test("uses trimmed stderr for a nonzero status", () => {
    const result = commandResult({ status: 2, stderr: Buffer.from("  template failed\n") });

    expect(() => requireSuccess(result)).toThrow("template failed");
  });

  test("falls back to the status when stderr is empty", () => {
    const result = commandResult({ status: 17 });

    expect(() => requireSuccess(result)).toThrow("chezmoi: exited with status 17");
  });
});
