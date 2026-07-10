import { promises as fs } from "node:fs";
import path from "node:path";

import {
  requireSuccess,
  runCommand,
  type ChezmoiRuntime,
  type CommandRunner,
} from "./worktree-runtime.ts";

export type SessionPaths = {
  activeDir: string;
  cacheDir: string;
  configFile: string;
  destinationDir: string;
  persistentStateFile: string;
  readyFile: string;
  snapshotSourceDir: string;
  stagedSourceDir: string;
  worktreeRoot: string;
};

export function resolveSessionBase(
  platform: NodeJS.Platform,
  homeDir: string,
  env: NodeJS.ProcessEnv,
): string {
  if (platform === "win32") {
    return path.win32.join(
      env.LOCALAPPDATA ?? path.win32.join(homeDir, "AppData", "Local"),
      "chezmoi-worktree-test",
    );
  }
  if (platform === "darwin") {
    return path.join(homeDir, "Library", "Application Support", "chezmoi-worktree-test");
  }
  return path.join(
    env.XDG_STATE_HOME ?? path.join(homeDir, ".local", "state"),
    "chezmoi-worktree-test",
  );
}

function buildSessionPaths(
  sessionBase: string,
  worktreeRoot: string,
  destinationDir: string,
): SessionPaths {
  const activeDir = path.join(sessionBase, "active");
  return {
    activeDir,
    cacheDir: path.join(activeDir, "cache"),
    configFile: path.join(activeDir, "config.toml"),
    destinationDir,
    persistentStateFile: path.join(activeDir, "state.boltdb"),
    readyFile: path.join(activeDir, "ready"),
    snapshotSourceDir: path.join(activeDir, "snapshot-source"),
    stagedSourceDir: path.join(activeDir, "staged-source"),
    worktreeRoot,
  };
}

export async function createActiveSession(
  sessionBase: string,
  worktreeRoot: string,
  destinationDir: string,
): Promise<SessionPaths> {
  const session = buildSessionPaths(sessionBase, worktreeRoot, destinationDir);
  await fs.mkdir(sessionBase, { mode: 0o700, recursive: true });
  try {
    await fs.mkdir(session.activeDir, { mode: 0o700, recursive: false });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "EEXIST") {
      throw new Error("an active worktree test session already exists");
    }
    throw error;
  }
  await fs.mkdir(session.cacheDir, { mode: 0o700 });
  await fs.mkdir(session.snapshotSourceDir, { mode: 0o700 });
  await fs.writeFile(session.configFile, "", { mode: 0o600 });
  return session;
}

export async function openActiveSession(
  sessionBase: string,
  worktreeRoot: string,
  destinationDir: string,
): Promise<SessionPaths> {
  const session = buildSessionPaths(sessionBase, worktreeRoot, destinationDir);
  await fs.stat(session.activeDir);
  return session;
}

export function stagedRuntime(session: SessionPaths): ChezmoiRuntime {
  return sessionRuntime(session, session.stagedSourceDir);
}

export function snapshotRuntime(session: SessionPaths): ChezmoiRuntime {
  return {
    ...sessionRuntime(session, session.snapshotSourceDir),
    worktreeRoot: session.activeDir,
  };
}

function sessionRuntime(session: SessionPaths, sourceDir: string): ChezmoiRuntime {
  return {
    cacheDir: session.cacheDir,
    configFile: session.configFile,
    destinationDir: session.destinationDir,
    persistentStateFile: session.persistentStateFile,
    sourceDir,
    worktreeRoot: session.worktreeRoot,
  };
}

export function resolveNormalSourceCheckout(
  worktreeRoot: string,
  runner?: CommandRunner,
): string {
  const result = requireSuccess(
    runCommand("git", ["-C", worktreeRoot, "rev-parse", "--git-common-dir"], runner),
    "resolve git common directory",
  );
  const gitDir = path.resolve(worktreeRoot, result.stdout.toString("utf8").trim());
  return path.dirname(gitDir);
}

export async function stageWorktreeSource(
  sourceDir: string,
  session: SessionPaths,
): Promise<void> {
  await fs.cp(sourceDir, session.stagedSourceDir, {
    errorOnExist: true,
    force: false,
    recursive: true,
    verbatimSymlinks: true,
  });
}

const FORBIDDEN_ATTRIBUTE = /^(?:run_|modify_|encrypted_|(?:(?:remove_|external_)*)exact_)/;
const FORBIDDEN_SPECIAL = /^\.chezmoiexternal(?:s|\.)|^\.chezmoiscripts$/;

export async function validateStagedSource(sourceDir: string): Promise<void> {
  const sourceStat = await fs.lstat(sourceDir);
  if (sourceStat.isSymbolicLink()) {
    throw new Error("unsupported source symlink: .");
  }
  if (!sourceStat.isDirectory()) {
    throw new Error("unsupported source node: .");
  }
  await validateSourceDirectory(sourceDir, "");
}

async function validateSourceDirectory(directoryPath: string, relativeDirectory: string) {
  const directory = await fs.opendir(directoryPath);
  for await (const entry of directory) {
    validateSourceComponent(entry.name);
    const relativePath = relativeDirectory
      ? path.posix.join(relativeDirectory, entry.name)
      : entry.name;
    const absolutePath = path.join(directoryPath, entry.name);

    if (entry.isSymbolicLink()) {
      throw new Error(`unsupported source symlink: ${relativePath}`);
    }
    if (entry.isDirectory()) {
      await validateSourceDirectory(absolutePath, relativePath);
    } else if (!entry.isFile()) {
      throw new Error(`unsupported source node: ${relativePath}`);
    }
  }
}

function validateSourceComponent(component: string): void {
  if (component.startsWith("literal_")) return;
  if (FORBIDDEN_ATTRIBUTE.test(component)) {
    throw new Error(`unsupported source attribute: ${component}`);
  }
  if (FORBIDDEN_SPECIAL.test(component)) {
    throw new Error(`unsupported special source path: ${component}`);
  }
}

export async function markSessionReady(session: SessionPaths): Promise<void> {
  const temporary = `${session.readyFile}.tmp`;
  await fs.writeFile(temporary, "ready\n", { flag: "wx", mode: 0o600 });
  await fs.rename(temporary, session.readyFile);
}

export async function removeActiveSession(session: SessionPaths): Promise<void> {
  await fs.rm(session.activeDir, { force: true, recursive: true });
}
