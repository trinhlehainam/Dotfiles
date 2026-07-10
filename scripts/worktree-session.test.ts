import { describe, expect, test } from "bun:test";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  createActiveSession,
  markSessionReady,
  openActiveSession,
  removeActiveSession,
  resolveNormalSourceCheckout,
  resolveSessionBase,
  snapshotRuntime,
  stageWorktreeSource,
  stagedRuntime,
  validateStagedSource,
} from "./worktree-session.ts";
import type { CommandResult, CommandRunner } from "./worktree-runtime.ts";

test("resolves per-platform state roots", () => {
  expect(resolveSessionBase("linux", "/home/u", { XDG_STATE_HOME: "/state" })).toBe(
    "/state/chezmoi-worktree-test",
  );
  expect(resolveSessionBase("darwin", "/Users/u", {})).toBe(
    "/Users/u/Library/Application Support/chezmoi-worktree-test",
  );
  expect(resolveSessionBase("win32", "C:\\Users\\u", { LOCALAPPDATA: "C:\\Local" })).toBe(
    "C:\\Local\\chezmoi-worktree-test",
  );
  expect(resolveSessionBase("linux", "/home/u", {})).toBe(
    "/home/u/.local/state/chezmoi-worktree-test",
  );
  expect(resolveSessionBase("win32", "C:\\Users\\u", {})).toBe(
    "C:\\Users\\u\\AppData\\Local\\chezmoi-worktree-test",
  );
});

test("writes ready only after explicit mark", async () => {
  const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
  const session = await createActiveSession(base, "/repo", "/home/u");

  await expect(fs.stat(session.readyFile)).rejects.toMatchObject({ code: "ENOENT" });
  await markSessionReady(session);

  expect(await fs.readFile(session.readyFile, "utf8")).toBe("ready\n");
  expect((await fs.stat(session.readyFile)).mode & 0o777).toBe(0o600);
});

describe("active session lifecycle", () => {
  test("creates the exact isolated paths with restrictive modes", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");

    expect(session).toEqual({
      activeDir: path.join(base, "active"),
      cacheDir: path.join(base, "active", "cache"),
      configFile: path.join(base, "active", "config.toml"),
      destinationDir: "/home/u",
      persistentStateFile: path.join(base, "active", "state.boltdb"),
      readyFile: path.join(base, "active", "ready"),
      snapshotSourceDir: path.join(base, "active", "snapshot-source"),
      stagedSourceDir: path.join(base, "active", "staged-source"),
      worktreeRoot: "/repo",
    });
    expect((await fs.stat(session.activeDir)).mode & 0o777).toBe(0o700);
    expect((await fs.stat(session.cacheDir)).mode & 0o777).toBe(0o700);
    expect((await fs.stat(session.snapshotSourceDir)).mode & 0o777).toBe(0o700);
    expect((await fs.stat(session.configFile)).mode & 0o777).toBe(0o600);
    expect(await fs.readFile(session.configFile, "utf8")).toBe("");
    await expect(fs.stat(session.stagedSourceDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("rejects a second active session with the stable lock error", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    await createActiveSession(base, "/repo", "/home/u");

    await expect(createActiveSession(base, "/repo", "/home/u")).rejects.toThrow(
      "an active worktree test session already exists",
    );
  });

  test("opens an existing session and rejects a missing session", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const created = await createActiveSession(base, "/repo", "/home/u");

    expect(await openActiveSession(base, "/repo", "/home/u")).toEqual(created);
    await removeActiveSession(created);
    await expect(openActiveSession(base, "/repo", "/home/u")).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  test("removes only the exact active directory", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const sibling = path.join(base, "keep");
    await fs.writeFile(sibling, "keep\n");
    const session = await createActiveSession(base, "/repo", "/home/u");

    await removeActiveSession(session);

    await expect(fs.stat(session.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
    expect(await fs.readFile(sibling, "utf8")).toBe("keep\n");
  });
});

test("projects staged and snapshot runtimes without changing destination state", async () => {
  const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
  const session = await createActiveSession(base, "/repo", "/home/u");

  expect(stagedRuntime(session)).toEqual({
    cacheDir: session.cacheDir,
    configFile: session.configFile,
    destinationDir: "/home/u",
    persistentStateFile: session.persistentStateFile,
    sourceDir: session.stagedSourceDir,
    worktreeRoot: "/repo",
  });
  expect(snapshotRuntime(session)).toEqual({
    cacheDir: session.cacheDir,
    configFile: session.configFile,
    destinationDir: "/home/u",
    persistentStateFile: session.persistentStateFile,
    sourceDir: session.snapshotSourceDir,
    worktreeRoot: session.activeDir,
  });
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

describe("resolveNormalSourceCheckout", () => {
  test("resolves the normal checkout from the shared git directory", () => {
    let invocation: { args: string[]; command: string } | undefined;
    const runner: CommandRunner = (command, args) => {
      invocation = { args, command };
      return commandResult({ stdout: Buffer.from("../normal/.git\n") });
    };

    expect(resolveNormalSourceCheckout("/repo/worktree", runner)).toBe("/repo/normal");
    expect(invocation).toEqual({
      command: "git",
      args: ["-C", "/repo/worktree", "rev-parse", "--git-common-dir"],
    });
  });

  test("uses stable context for git resolution failures", () => {
    const runner: CommandRunner = () =>
      commandResult({ status: 128, stderr: Buffer.from("not a worktree\n") });

    expect(() => resolveNormalSourceCheckout("/repo/worktree", runner)).toThrow(
      "not a worktree",
    );
  });
});

describe("stageWorktreeSource", () => {
  test("copies the source recursively into the initially absent staged directory", async () => {
    const source = await makeSourceFixture("dot_config/tool/config.toml");
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");

    await stageWorktreeSource(source, session);

    expect(
      await fs.readFile(
        path.join(session.stagedSourceDir, "dot_config", "tool", "config.toml"),
        "utf8",
      ),
    ).toBe("fixture\n");
  });

  test("preserves source symlinks instead of dereferencing them", async () => {
    const source = await makeSourceFixture("dot_target");
    await fs.symlink("dot_target", path.join(source, "dot_link"));
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");

    await stageWorktreeSource(source, session);

    expect(await fs.readlink(path.join(session.stagedSourceDir, "dot_link"))).toBe("dot_target");
  });

  test("does not overwrite an existing staged source", async () => {
    const source = await makeSourceFixture("dot_file");
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");
    await fs.mkdir(session.stagedSourceDir);
    const existingFile = path.join(session.stagedSourceDir, "dot_file");
    await fs.writeFile(existingFile, "existing\n");

    await expect(stageWorktreeSource(source, session)).rejects.toThrow("already exists");
    expect(await fs.readFile(existingFile, "utf8")).toBe("existing\n");
  });
});

test.each([
  ["run_probe", "unsupported source attribute: run_probe"],
  ["modify_dot_file", "unsupported source attribute: modify_dot_file"],
  ["exact_dot_config", "unsupported source attribute: exact_dot_config"],
  ["encrypted_dot_secret", "unsupported source attribute: encrypted_dot_secret"],
  ["remove_exact_dot_cache", "unsupported source attribute: remove_exact_dot_cache"],
  ["external_exact_dot_cache", "unsupported source attribute: external_exact_dot_cache"],
  [".chezmoiscripts/run_probe", "unsupported special source path: .chezmoiscripts"],
  [".chezmoiexternal.toml", "unsupported special source path: .chezmoiexternal.toml"],
] as const)("rejects %s", async (relativePath, message) => {
  const source = await makeSourceFixture(relativePath);
  await expect(validateStagedSource(source)).rejects.toThrow(message);
});

test("rejects exact directories", async () => {
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  await fs.mkdir(path.join(source, "exact_dot_config"));

  await expect(validateStagedSource(source)).rejects.toThrow(
    "unsupported source attribute: exact_dot_config",
  );
});

test("accepts ordinary, remove, and literal-prefixed source components", async () => {
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  for (const relativePath of [
    "dot_file",
    "remove_dot_old",
    "literal_run_probe",
    "literal_modify_dot_file",
    "literal_exact_dot_config",
    "literal_encrypted_dot_secret",
  ]) {
    await writeSourceFixture(source, relativePath);
  }

  await expect(validateStagedSource(source)).resolves.toBeUndefined();
});

test("rejects source symlinks without following them", async () => {
  const source = await makeSourceFixture("dot_target");
  await fs.symlink("dot_target", path.join(source, "dot_link"));

  await expect(validateStagedSource(source)).rejects.toThrow(
    "unsupported source symlink: dot_link",
  );
});

test("rejects a symlink used as the source root", async () => {
  const source = await makeSourceFixture("dot_file");
  const sourceLink = `${source}-link`;
  await fs.symlink(source, sourceLink, "dir");

  await expect(validateStagedSource(sourceLink)).rejects.toThrow(
    "unsupported source symlink: .",
  );
});

test("rejects special source nodes", async () => {
  if (process.platform === "win32") return;
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  const fifo = path.join(source, "dot_pipe");
  const processResult = Bun.spawn(["mkfifo", fifo], { stderr: "pipe" });
  expect(await processResult.exited).toBe(0);

  await expect(validateStagedSource(source)).rejects.toThrow(
    "unsupported source node: dot_pipe",
  );
});

async function makeSourceFixture(relativePath: string): Promise<string> {
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  await writeSourceFixture(source, relativePath);
  return source;
}

async function writeSourceFixture(source: string, relativePath: string): Promise<void> {
  const target = path.join(source, ...relativePath.split("/"));
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, "fixture\n");
}
