import { spawnSync } from "node:child_process";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

export type ChezmoiRuntime = {
  cacheDir: string;
  configFile: string;
  destinationDir: string;
  persistentStateFile: string;
  sourceDir: string;
  worktreeRoot: string;
};

export type CommandResult = {
  error?: Error;
  signal: NodeJS.Signals | null;
  status: number | null;
  stderr: Buffer;
  stdout: Buffer;
};

export type CommandRunner = (command: string, args: string[]) => CommandResult;

export function buildChezmoiArgs(runtime: ChezmoiRuntime, commandArgs: string[]): string[] {
  return [
    "--source",
    runtime.sourceDir,
    "--working-tree",
    runtime.worktreeRoot,
    "--config",
    runtime.configFile,
    "--cache",
    runtime.cacheDir,
    "--persistent-state",
    runtime.persistentStateFile,
    "--destination",
    runtime.destinationDir,
    ...commandArgs,
  ];
}

const defaultRunner: CommandRunner = (command, args) => {
  const result = spawnSync(command, args, { encoding: "buffer" });
  return {
    error: result.error,
    signal: result.signal,
    status: result.status,
    stderr: result.stderr ?? Buffer.alloc(0),
    stdout: result.stdout ?? Buffer.alloc(0),
  };
};

export const streamCommand: CommandRunner = (command, args) => {
  const result = spawnSync(command, args, { stdio: "inherit" });
  return {
    error: result.error,
    signal: result.signal,
    status: result.status,
    stderr: Buffer.alloc(0),
    stdout: Buffer.alloc(0),
  };
};

export function runChezmoi(
  runtime: ChezmoiRuntime,
  commandArgs: string[],
  runner: CommandRunner = defaultRunner,
): CommandResult {
  return runCommand("chezmoi", buildChezmoiArgs(runtime, commandArgs), runner);
}

export function runCommand(
  command: string,
  args: string[],
  runner: CommandRunner = defaultRunner,
): CommandResult {
  return runner(command, args);
}

export function requireSuccess(result: CommandResult, context = "chezmoi"): CommandResult {
  if (result.error !== undefined) throw new Error(`${context}: ${result.error.message}`);
  if (result.signal !== null) throw new Error(`${context}: terminated by ${result.signal}`);
  if (result.status !== 0) {
    const stderr = result.stderr.toString("utf8").trim();
    throw new Error(stderr || `${context}: exited with status ${result.status ?? 1}`);
  }
  return result;
}

const runtimeRoots = new WeakMap<ChezmoiRuntime, string>();

export async function createEphemeralRuntime(options: {
  destinationDir: string;
  sourceDir: string;
  tempParent?: string;
  worktreeRoot: string;
}): Promise<ChezmoiRuntime> {
  const root = await fs.mkdtemp(path.join(options.tempParent ?? os.tmpdir(), "chezmoi-worktree-"));
  const runtime: ChezmoiRuntime = {
    cacheDir: path.join(root, "cache"),
    configFile: path.join(root, "config.toml"),
    destinationDir: options.destinationDir,
    persistentStateFile: path.join(root, "state.boltdb"),
    sourceDir: options.sourceDir,
    worktreeRoot: options.worktreeRoot,
  };

  try {
    await fs.mkdir(runtime.cacheDir, { mode: 0o700 });
    await fs.writeFile(runtime.configFile, "", { mode: 0o600 });
  } catch (error) {
    await fs.rm(root, { force: true, recursive: true });
    throw error;
  }
  runtimeRoots.set(runtime, root);
  return runtime;
}

export async function removeEphemeralRuntime(runtime: ChezmoiRuntime): Promise<void> {
  const root = runtimeRoots.get(runtime);
  if (root !== undefined) {
    await fs.rm(root, { force: true, recursive: true });
    runtimeRoots.delete(runtime);
  }
}
