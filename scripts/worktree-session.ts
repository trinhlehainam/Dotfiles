import { promises as fs } from "node:fs";
import path from "node:path";

import {
  requireSuccess,
  runChezmoi,
  runCommand,
  type ChezmoiRuntime,
  type CommandResult,
  type CommandRunner,
} from "./worktree-runtime.ts";

export type ManagedKind = "directory" | "file" | "remove" | "symlink";

export type CandidateTarget = {
  absolutePath: string;
  baselineKind?: "absent" | "directory" | "file" | "symlink";
  managedKind: ManagedKind;
  relativePath?: string;
  snapshotCovered?: boolean;
};

export type PlannedChange = {
  action: "A" | "D" | "M";
  absolutePath: string;
};

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

const managedOutputDecoder = new TextDecoder("utf-8", { fatal: true });

export function parseNulPaths(output: Buffer): string[] {
  if (output.length === 0) return [];
  if (output.at(-1) !== 0) throw new Error("managed output is not NUL-terminated");
  let decoded: string;
  try {
    decoded = managedOutputDecoder.decode(output.subarray(0, -1));
  } catch {
    throw new Error("managed output is not valid UTF-8");
  }
  const paths = decoded.split("\0");
  if (paths.some((managedPath) => managedPath.length === 0)) {
    throw new Error("managed output contains an empty path");
  }
  return paths;
}

export function parseStatus(output: string): PlannedChange[] {
  return output
    .split("\n")
    .filter((line) => line.length > 0)
    .map((line) => {
      if (line.length < 4 || line[2] !== " ") {
        throw new Error(`malformed status line: ${line}`);
      }
      const action = line[1];
      if (action === "R") throw new Error(`unsupported script status: ${line}`);
      if (action !== "A" && action !== "D" && action !== "M") {
        throw new Error(`unsupported status action: ${line}`);
      }
      return { action, absolutePath: line.slice(3) };
    });
}

export function validateCoverage(
  planned: PlannedChange[],
  candidates: Map<string, CandidateTarget>,
): void {
  for (const change of planned) {
    const candidate = candidates.get(path.normalize(change.absolutePath));
    if (candidate === undefined) {
      throw new Error(`status path has no snapshot coverage: ${change.absolutePath}`);
    }
    if (candidate.managedKind === "directory") {
      if (candidate.baselineKind === "absent" && change.action === "A") continue;
      throw new Error(`unsupported existing directory change: ${change.absolutePath}`);
    }
    if (candidate.snapshotCovered !== true) {
      throw new Error(`status path has no snapshot coverage: ${change.absolutePath}`);
    }
  }
}

export type Question = (prompt: string) => Promise<string>;

export async function confirmPaths(
  planned: PlannedChange[],
  yes: boolean,
  question: Question,
): Promise<boolean> {
  if (yes) return true;
  const lines = planned.map(({ action, absolutePath }) => `${action} ${absolutePath}`).join("\n");
  const answer = await question(`${lines}\nApply these changes? [y/N] `);
  return answer.trim().toLowerCase() === "y";
}

export async function applyPlannedChanges(
  runtime: ChezmoiRuntime,
  planned: PlannedChange[],
  runner?: CommandRunner,
): Promise<CommandResult> {
  if (planned.length === 0) {
    return {
      signal: null,
      status: 0,
      stderr: Buffer.alloc(0),
      stdout: Buffer.alloc(0),
    };
  }
  return runChezmoi(
    runtime,
    [
      "--force",
      "apply",
      "--exclude",
      "scripts,externals,encrypted",
      ...planned.map(({ absolutePath }) => absolutePath),
    ],
    runner,
  );
}

export function validateSafeRemovalPath(relativePath: string): void {
  if (
    relativePath.trim() !== relativePath ||
    /^[!#]/.test(relativePath) ||
    /[\r\n*?\[\]{}]/.test(relativePath)
  ) {
    throw new Error(`unsafe removal path: ${relativePath}`);
  }
}

const MANAGED_INCLUDE: Record<ManagedKind, string> = {
  directory: "dirs",
  file: "files",
  symlink: "symlinks",
  remove: "remove",
};

export async function enumerateCandidates(
  runtime: ChezmoiRuntime,
  runner?: CommandRunner,
): Promise<Map<string, CandidateTarget>> {
  const candidates = new Map<string, CandidateTarget>();
  for (const [managedKind, include] of Object.entries(MANAGED_INCLUDE) as Array<
    [ManagedKind, string]
  >) {
    const result = requireSuccess(
      runChezmoi(
        runtime,
        ["managed", "--include", include, "--path-style", "absolute", "--nul-path-separator"],
        runner,
      ),
      `enumerate ${managedKind} targets`,
    );
    for (const absolutePath of parseNulPaths(result.stdout)) {
      if (!path.isAbsolute(absolutePath)) {
        throw new Error(`managed output path is not absolute: ${absolutePath}`);
      }
      const normalized = path.normalize(absolutePath);
      const previous = candidates.get(normalized);
      if (previous !== undefined && previous.managedKind !== managedKind) {
        throw new Error(`conflicting managed target types: ${normalized}`);
      }
      candidates.set(normalized, { absolutePath: normalized, managedKind });
    }
  }
  return candidates;
}

export function isPathInside(root: string, candidate: string): boolean {
  const relativePath = path.relative(root, candidate);
  return (
    relativePath === "" ||
    (relativePath !== ".." &&
      !relativePath.startsWith(`..${path.sep}`) &&
      !path.isAbsolute(relativePath))
  );
}

export async function inspectCandidates(
  candidates: Map<string, CandidateTarget>,
  options: {
    destinationDir: string;
    normalSourceDir: string;
    sessionDir: string;
    worktreeRoot: string;
  },
): Promise<void> {
  const destinationDir = path.normalize(options.destinationDir);
  const protectedRoots = [
    [options.sessionDir, "session directory"],
    [options.worktreeRoot, "worktree root"],
    [options.normalSourceDir, "normal source directory"],
  ] as const;

  for (const candidate of candidates.values()) {
    if (/[\r\n]/.test(candidate.absolutePath)) {
      throw new Error(`managed target contains CR or LF: ${candidate.absolutePath}`);
    }

    const absolutePath = path.normalize(candidate.absolutePath);
    if (!isPathInside(destinationDir, absolutePath)) {
      throw new Error(`managed target is outside destination: ${absolutePath}`);
    }
    for (const [protectedRoot, label] of protectedRoots) {
      if (isPathInside(path.normalize(protectedRoot), absolutePath)) {
        throw new Error(`managed target is inside ${label}: ${absolutePath}`);
      }
    }

    await rejectSymlinkedAncestors(destinationDir, absolutePath);
    const relativePath = path.relative(destinationDir, absolutePath).split(path.sep).join("/");
    let targetStat;
    try {
      targetStat = await fs.lstat(absolutePath);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      candidate.baselineKind = "absent";
      candidate.relativePath = relativePath;
      continue;
    }

    if (targetStat.isFile()) {
      candidate.baselineKind = "file";
    } else if (targetStat.isSymbolicLink()) {
      candidate.baselineKind = "symlink";
    } else if (targetStat.isDirectory()) {
      if (candidate.managedKind !== "directory") {
        throw new Error(
          `managed non-directory target is an existing directory: ${absolutePath}`,
        );
      }
      candidate.baselineKind = "directory";
    } else {
      throw new Error(`unsupported destination node: ${absolutePath}`);
    }
    candidate.relativePath = relativePath;
  }
}

async function rejectSymlinkedAncestors(
  destinationDir: string,
  absolutePath: string,
): Promise<void> {
  const relativeParent = path.relative(destinationDir, path.dirname(absolutePath));
  const components = relativeParent === "" ? [] : relativeParent.split(path.sep);
  let ancestor = destinationDir;

  for (let index = 0; index <= components.length; index += 1) {
    let ancestorStat;
    try {
      ancestorStat = await fs.lstat(ancestor);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return;
      throw error;
    }
    if (ancestorStat.isSymbolicLink()) {
      throw new Error(`managed target has symlinked ancestor: ${ancestor}`);
    }
    if (!ancestorStat.isDirectory()) {
      throw new Error(`unsupported destination ancestor: ${ancestor}`);
    }
    ancestor = path.join(ancestor, components[index] ?? "");
  }
}

export async function captureSnapshot(
  session: SessionPaths,
  candidates: Map<string, CandidateTarget>,
  runner?: CommandRunner,
): Promise<void> {
  const runtime = snapshotRuntime(session);
  const absentCandidates: CandidateTarget[] = [];

  for (const candidate of candidates.values()) {
    if (candidate.baselineKind === "file" || candidate.baselineKind === "symlink") {
      requireSuccess(
        runChezmoi(runtime, ["add", candidate.absolutePath], runner),
        `capture ${candidate.absolutePath}`,
      );
      candidate.snapshotCovered = true;
      continue;
    }
    if (candidate.baselineKind === "absent" && candidate.managedKind !== "directory") {
      validateSafeRemovalPath(candidate.relativePath!);
      absentCandidates.push(candidate);
    }
  }

  if (absentCandidates.length > 0) {
    const target = path.join(session.snapshotSourceDir, ".chezmoiremove");
    const temporary = `${target}.tmp`;
    const absentPaths = absentCandidates.map((candidate) => candidate.relativePath!).sort();
    await fs.writeFile(temporary, `${absentPaths.join("\n")}\n`, { mode: 0o600 });
    await fs.rename(temporary, target);
    for (const candidate of absentCandidates) candidate.snapshotCovered = true;
  }

  requireSuccess(runChezmoi(runtime, ["verify"], runner), "verify captured snapshot");
}

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
