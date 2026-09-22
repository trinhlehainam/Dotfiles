import { promises as fs } from "node:fs";
import path from "node:path";

import { resolveSourceStateRoot } from "./chezmoi-paths.ts";
import { reconcileAllTools } from "./reconcile-configs.ts";
import {
  requireSuccess,
  runChezmoi,
  runCommand,
  type ChezmoiRuntime,
  type CommandRunner,
} from "./worktree-runtime.ts";

export type ManagedKind = "directory" | "file" | "remove" | "symlink";

export type CandidateTarget = {
  absolutePath: string;
  managedKind: ManagedKind;
};

export type InspectedTarget = CandidateTarget & {
  baselineKind: "absent" | "directory" | "file" | "symlink";
  relativePath: string;
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

export type Question = (prompt: string) => Promise<string>;

function runForTargets(
  runtime: ChezmoiRuntime,
  commandArgs: string[],
  targets: string[],
  runner?: CommandRunner,
): void {
  // Bound command size, and never turn an empty target list into an unscoped apply.
  for (let offset = 0; offset < targets.length; offset += 100) {
    requireSuccess(
      runChezmoi(runtime, [...commandArgs, "--", ...targets.slice(offset, offset + 100)], runner),
      `chezmoi ${commandArgs.join(" ")}`,
    );
  }
}

export function validateSafeRemovalPath(relativePath: string): void {
  if (
    relativePath.length === 0 ||
    relativePath.trim() !== relativePath ||
    relativePath.startsWith("!") ||
    /[\\#\r\n*?\[\]{}]/.test(relativePath)
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
    normalSourceDir?: string;
    restoring?: boolean;
    sessionDir: string;
    worktreeRoot: string;
  },
): Promise<Map<string, InspectedTarget>> {
  const destinationDir = path.normalize(options.destinationDir);
  const inspected = new Map<string, InspectedTarget>();
  const protectedRoots = [
    [options.sessionDir, "session directory"],
    [options.worktreeRoot, "worktree root"],
    ...(options.normalSourceDir === undefined
      ? []
      : [[options.normalSourceDir, "normal source directory"] as const]),
  ] as const;

  for (const candidate of candidates.values()) {
    if (/[\r\n]/.test(candidate.absolutePath)) {
      throw new Error(`managed target contains CR or LF: ${candidate.absolutePath}`);
    }

    const absolutePath = path.normalize(candidate.absolutePath);
    if (absolutePath === destinationDir || !isPathInside(destinationDir, absolutePath)) {
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
      inspected.set(candidate.absolutePath, { ...candidate, baselineKind: "absent", relativePath });
      continue;
    }

    let baselineKind: InspectedTarget["baselineKind"];
    if (targetStat.isFile()) {
      if (targetStat.nlink > 1) {
        throw new Error(`unsupported hard-linked target: ${absolutePath}`);
      }
      baselineKind = "file";
    } else if (targetStat.isSymbolicLink()) {
      baselineKind = "symlink";
    } else if (targetStat.isDirectory()) {
      if (candidate.managedKind === "remove" && options.restoring) {
        // Removal rules delete whole directories. Never remove uncaptured contents.
        for (const name of await fs.readdir(absolutePath)) {
          const child = path.join(absolutePath, name);
          if (!candidates.has(child)) {
            throw new Error(`cannot revert directory containing uncaptured path: ${child}`);
          }
        }
      } else if (candidate.managedKind !== "directory") {
        throw new Error(
          `managed non-directory target is an existing directory: ${absolutePath}`,
        );
      }
      baselineKind = "directory";
    } else {
      throw new Error(`unsupported destination node: ${absolutePath}`);
    }
    if (candidate.managedKind === "directory" && baselineKind !== "directory") {
      throw new Error(`unsupported directory type change: ${absolutePath}`);
    }
    inspected.set(candidate.absolutePath, { ...candidate, baselineKind, relativePath });
  }
  return inspected;
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
  candidates: Map<string, InspectedTarget>,
  runner?: CommandRunner,
): Promise<void> {
  const runtime = snapshotRuntime(session);
  const existing: string[] = [];
  const absent: string[] = [];

  for (const candidate of candidates.values()) {
    if (candidate.baselineKind === "absent") {
      validateSafeRemovalPath(candidate.relativePath);
      absent.push(candidate.relativePath);
    } else {
      existing.push(candidate.absolutePath);
    }
  }

  // Capture directory modes without including unmanaged children:
  // https://www.chezmoi.io/reference/commands/add/#-r---recursive
  runForTargets(runtime, ["add", "--recursive=false"], existing, runner);
  if (absent.length > 0) {
    await fs.writeFile(
      path.join(session.snapshotSourceDir, ".chezmoiremove"),
      `${absent.sort().join("\n")}\n`,
      { mode: 0o600 },
    );
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

// Only capture-time scaffolding is tracked here; recovery data stays in chezmoi's source.
const createdStateRoots = new WeakMap<SessionPaths, string>();

export async function createActiveSession(
  sessionBase: string,
  worktreeRoot: string,
  destinationDir: string,
): Promise<SessionPaths> {
  const session = buildSessionPaths(sessionBase, worktreeRoot, destinationDir);
  const createdRoot = await fs.mkdir(sessionBase, { mode: 0o700, recursive: true });
  if (createdRoot !== undefined) createdStateRoots.set(session, createdRoot);
  try {
    await fs.mkdir(session.activeDir, { mode: 0o700, recursive: false });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "EEXIST") {
      throw new Error("an active worktree test session already exists; run pnpm run worktree:revert");
    }
    throw error;
  }
  try {
    await fs.mkdir(session.cacheDir, { mode: 0o700 });
    await fs.mkdir(session.snapshotSourceDir, { mode: 0o700 });
    await fs.writeFile(session.configFile, "", { mode: 0o600 });
    await fs.writeFile(
      path.join(session.activeDir, "session.json"),
      JSON.stringify({
        destinationDir: path.resolve(destinationDir),
        worktreeRoot: path.resolve(worktreeRoot),
      }),
      { flag: "wx", mode: 0o600 },
    );
  } catch (error) {
    await removeActiveSession(session);
    throw error;
  }
  return session;
}

export async function openActiveSession(
  sessionBase: string,
  worktreeRoot: string,
  destinationDir: string,
): Promise<SessionPaths> {
  const session = buildSessionPaths(sessionBase, worktreeRoot, destinationDir);
  await fs.stat(session.activeDir);
  await requireReadySession(session);
  const identity = JSON.parse(await fs.readFile(path.join(session.activeDir, "session.json"), "utf8"));
  if (identity?.destinationDir !== path.resolve(destinationDir)) {
    throw new Error(`active session destination does not match: ${session.activeDir}`);
  }
  if (typeof identity.worktreeRoot !== "string" || !path.isAbsolute(identity.worktreeRoot)) {
    throw new Error(`invalid session owner: ${session.activeDir}`);
  }
  return buildSessionPaths(sessionBase, identity.worktreeRoot, destinationDir);
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
    runCommand("git", ["-C", worktreeRoot, "worktree", "list", "--porcelain", "-z"], runner),
    "resolve main worktree",
  );
  // Git lists the main checkout (or bare repository itself) first.
  const end = result.stdout.indexOf(0);
  const first = result.stdout.subarray(0, end).toString("utf8");
  const root = first.slice("worktree ".length);
  if (end < 0 || !first.startsWith("worktree ") || !path.isAbsolute(root)) {
    throw new Error("invalid main worktree path from git");
  }
  return path.normalize(root);
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

const FORBIDDEN_ATTRIBUTE = /^(?:run_|modify_|(?:create_)?encrypted_|(?:(?:remove_|external_)*)exact_)/;
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
  await removeCreatedParents(path.dirname(session.activeDir), createdStateRoots.get(session));
}

async function removeCreatedParents(directory: string, createdRoot?: string): Promise<void> {
  if (createdRoot === undefined) return;
  while (isPathInside(createdRoot, directory)) {
    try {
      await fs.rmdir(directory);
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code === "ENOTEMPTY" || code === "EEXIST") return;
      if (code !== "ENOENT") throw error;
    }
    directory = path.dirname(directory);
  }
}

async function requireReadySession(session: SessionPaths): Promise<void> {
  try {
    await fs.stat(session.readyFile);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    // Never delete automatically: another apply may still be preparing this session.
    throw new Error(
      `Incomplete session. Stop any running worktree:apply process, then remove only this directory: ${session.activeDir}; retry pnpm run worktree:apply. Do not remove a session containing a ready file.`,
      { cause: error },
    );
  }
}

async function withOperationLock(
  sessionBase: string,
  operation: (createdRoot: string | undefined) => Promise<void>,
): Promise<void> {
  const createdRoot = await fs.mkdir(sessionBase, { mode: 0o700, recursive: true });
  const lockDir = path.join(sessionBase, "operation");
  try {
    await fs.mkdir(lockDir, { mode: 0o700 });
  } catch (error) {
    await removeCreatedParents(sessionBase, createdRoot);
    if ((error as NodeJS.ErrnoException).code === "EEXIST") {
      throw new Error(
        `worktree operation already in progress; if interrupted, stop all worktree commands, then remove only ${lockDir}; keep the active snapshot`,
      );
    }
    throw error;
  }
  try {
    await operation(createdRoot);
  } finally {
    await fs.rmdir(lockDir);
    await removeCreatedParents(sessionBase, createdRoot);
  }
}

async function restoreSnapshot(session: SessionPaths, runner?: CommandRunner): Promise<void> {
  try {
    await requireReadySession(session);
    const runtime = snapshotRuntime(session);
    await inspectCandidates(await enumerateCandidates(runtime, runner), {
      destinationDir: session.destinationDir,
      sessionDir: path.dirname(session.activeDir),
      worktreeRoot: session.worktreeRoot,
      restoring: true,
    });
    requireSuccess(runChezmoi(runtime, ["--force", "apply"], runner), "apply snapshot");
    requireSuccess(runChezmoi(runtime, ["verify"], runner), "verify restored snapshot");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(
      `${message}; session: ${session.activeDir}; run pnpm run worktree:revert`,
      { cause: error },
    );
  }
}

export async function revertActiveSession(options: {
  confirm: (lines: string[]) => Promise<boolean>;
  session: SessionPaths;
  runner?: CommandRunner;
}): Promise<void> {
  const { session: requested, runner } = options;
  await withOperationLock(path.dirname(requested.activeDir), async () => {
    const session = await openActiveSession(
      path.dirname(requested.activeDir), requested.worktreeRoot, requested.destinationDir,
    );
    const status = requireSuccess(
      runChezmoi(snapshotRuntime(session), ["status", "--path-style", "absolute"], runner),
      "read snapshot status",
    );
    const lines = status.stdout.toString("utf8").trimEnd().split("\n").filter(Boolean);
    lines.unshift(`Session owner: ${session.worktreeRoot}`);
    if (!(await options.confirm(lines))) {
      throw new Error("revert cancelled");
    }
    await restoreSnapshot(session, runner);
    await removeActiveSession(session);
    process.stderr.write("Restored and verified the pre-test dotfiles.\n");
  });
}

export async function runLiveApply(options: {
  destinationDir: string;
  question: Question;
  runner?: CommandRunner;
  sessionBase: string;
  worktreeRoot: string;
  yes: boolean;
}): Promise<void> {
  await withOperationLock(options.sessionBase, (createdRoot) => applyWorktree(options, createdRoot));
}

async function applyWorktree(
  options: Parameters<typeof runLiveApply>[0],
  createdRoot: string | undefined,
): Promise<void> {
  const sourceDir = resolveSourceStateRoot(options.worktreeRoot);
  const activeDir = path.join(options.sessionBase, "active");
  let reapplying = true;
  try {
    await fs.stat(activeDir);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    reapplying = false;
  }
  const session = reapplying
    ? await openActiveSession(options.sessionBase, options.worktreeRoot, options.destinationDir)
    : await createActiveSession(options.sessionBase, options.worktreeRoot, options.destinationDir);
  if (path.resolve(session.worktreeRoot) !== path.resolve(options.worktreeRoot)) {
    throw new Error(`HOME has an active test session owned by ${session.worktreeRoot}; run pnpm run worktree:revert before applying another worktree`);
  }
  let keepSession = reapplying;

  try {
    await reconcileAllTools({
      hostHome: options.destinationDir,
      repoRoot: options.worktreeRoot,
      sourceStateRoot: sourceDir,
    });
    if (reapplying) await fs.rm(session.stagedSourceDir, { force: true, recursive: true });
    await stageWorktreeSource(sourceDir, session);
    await validateStagedSource(session.stagedSourceDir);
    const candidates = await enumerateCandidates(stagedRuntime(session), options.runner);
    for (const target of candidates.keys()) {
      if (
        createdRoot !== undefined &&
        isPathInside(createdRoot, target) &&
        isPathInside(target, session.activeDir)
      ) {
        throw new Error(
          `recovery storage created a managed target: ${target}; create ${options.sessionBase} before retrying`,
        );
      }
    }
    if (candidates.size === 0 && !reapplying) {
      process.stderr.write("No supported managed targets to apply.\n");
      return;
    }
    const normalSourceDir = resolveNormalSourceCheckout(options.worktreeRoot, options.runner);
    const preflight = {
      destinationDir: options.destinationDir,
      normalSourceDir,
      sessionDir: options.sessionBase,
      worktreeRoot: options.worktreeRoot,
    };
    const inspected = await inspectCandidates(candidates, preflight);
    const inventoryFile = path.join(session.activeDir, "targets.json");
    if (reapplying) {
      let inventory: string;
      try {
        inventory = await fs.readFile(inventoryFile, "utf8");
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
        throw new Error("session has no target inventory; run pnpm run worktree:revert before applying again");
      }
      const captured = new Set<string>(JSON.parse(inventory));
      for (const target of candidates.keys()) {
        if (!captured.has(target)) {
          throw new Error(`uncaptured target: ${target}; run pnpm run worktree:revert before applying new targets`);
        }
      }
    } else {
      await captureSnapshot(session, inspected, options.runner);
      await fs.writeFile(inventoryFile, JSON.stringify([...candidates.keys()]), { flag: "wx", mode: 0o600 });
    }

    const status = requireSuccess(
      runChezmoi(
        stagedRuntime(session),
        [
          "status",
          "--path-style",
          "absolute",
          "--exclude",
          "scripts,externals,encrypted",
        ],
        options.runner,
      ),
      "read staged status",
    );
    if (!options.yes) {
      const preview = status.stdout.toString("utf8").trimEnd() || "Managed targets already match.";
      const action = reapplying
        ? "Restore the original baseline, then reapply this worktree to HOME?"
        : "Apply these targets to HOME?";
      const answer = await options.question(`${preview}\n${action} [y/N] `);
      if (answer.trim().toLowerCase() !== "y") return;
    }

    if (reapplying) {
      await restoreSnapshot(session, options.runner);
    } else {
      // The user may have edited a target while the confirmation prompt was open.
      requireSuccess(
        runChezmoi(snapshotRuntime(session), ["verify"], options.runner),
        "baseline changed before apply; retry worktree:apply",
      );
    }
    await inspectCandidates(candidates, preflight);
    // Commit the verified snapshot before HOME can change. From here, retain it
    // on failure until recovery has restored and verified the original baseline.
    if (!reapplying) await markSessionReady(session);
    keepSession = true;
    try {
      runForTargets(
        stagedRuntime(session),
        ["--force", "apply", "--recursive=false", "--exclude", "scripts,externals,encrypted"],
        [...candidates.keys()],
        options.runner,
      );
    } catch (applyError) {
      try {
        await restoreSnapshot(session, options.runner);
        await removeActiveSession(session);
      } catch (recoveryError) {
        const applyMessage = applyError instanceof Error ? applyError.message : String(applyError);
        const recoveryMessage = recoveryError instanceof Error ? recoveryError.message : String(recoveryError);
        throw new Error(
          `apply and automatic revert failed\nApply: ${applyMessage}\nRecovery: ${recoveryMessage}\nRun pnpm run worktree:revert; session: ${session.activeDir}`,
          { cause: recoveryError },
        );
      }
      throw applyError;
    }
    process.stderr.write(
      `Worktree applied. Snapshot: ${session.snapshotSourceDir}\nRun pnpm run worktree:revert to restore.\n`,
    );
  } finally {
    if (!keepSession) await removeActiveSession(session);
  }
}
