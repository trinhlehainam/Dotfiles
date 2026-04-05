import { Glob } from "bun";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";

export type PlatformKind = "unix" | "windows";
export type LogMode = "info" | "verbose" | "debug";

type LogLevel = "ERROR" | "INFO" | "VERBOSE" | "DEBUG";

type PlatformConfig = {
  kind: PlatformKind;
  wrapperRoot: string;
  targetPrefix: string;
  targetRoot: string;
};

type ExpectedWrapper = {
  platform: PlatformConfig;
  relativePath: string;
  wrapperPath: string;
  content: string;
};

type ExistingWrapper = {
  platform: PlatformConfig;
  wrapperPath: string;
};

type ReconcileRuntime = {
  hostKind: PlatformKind;
  hostHome: string;
  hostPlatform: PlatformConfig;
  logMode: LogMode;
  platforms: PlatformConfig[];
  platformConfigs: Record<PlatformKind, PlatformConfig>;
  rawRoot: string;
  removeManifestPath: string;
  repoRoot: string;
  logger: Logger;
};

type Logger = {
  error: (message: string) => void;
  info: (message: string) => void;
  verbose: (message: string) => void;
  debug: (message: string) => void;
};

type LogWriters = {
  stdout: (line: string) => void;
  stderr: (line: string) => void;
  now: () => Date;
};

export type ReconcileNvimOptions = {
  hostHome?: string;
  hostKind?: PlatformKind;
  logMode?: LogMode;
  now?: () => Date;
  rawRoot?: string;
  removeManifestPath?: string;
  repoRoot?: string;
  sourceStateRoot?: string;
  stderr?: (line: string) => void;
  stdout?: (line: string) => void;
};

export type ReconcileSummary = {
  added: number;
  host: PlatformKind;
  raw: number;
  removed: number;
  targetRoot: string;
};

export type RunCliOptions = ReconcileNvimOptions & {
  exit?: (code: number) => void;
};

const LOG_PREFIX = "[reconcile-nvim-config]";
const allFilesGlob = new Glob("**/*");
const wrapperFilesGlob = new Glob("**/*.tmpl");
const defaultRepoRoot = path.resolve(import.meta.dir, "..");
const defaultHostKind: PlatformKind = process.platform === "win32" ? "windows" : "unix";

export function tokenizeShellWords(value: string): string[] {
  // `CHEZMOI_ARGS` is a shell-style string, not a real argv array. Bun's docs
  // recommend `node:util.parseArgs` for flag parsing, but Bun/Node do not expose
  // a standard helper to split shell text from an env var into argv tokens.
  const tokens: string[] = [];
  let current = "";
  let quote: '"' | "'" | null = null;

  function pushCurrent(): void {
    if (current.length > 0) {
      tokens.push(current);
      current = "";
    }
  }

  for (let index = 0; index < value.length; index += 1) {
    const character = value.charAt(index);

    if (quote === null) {
      if (/\s/.test(character)) {
        pushCurrent();
        continue;
      }

      if (character === '"' || character === "'") {
        quote = character;
        continue;
      }

      if (character === "\\") {
        if (index + 1 < value.length) {
          const nextCharacter = value.charAt(index + 1);
          current += nextCharacter;
          index += 1;
          continue;
        }
      }

      current += character;
      continue;
    }

    if (character === quote) {
      quote = null;
      continue;
    }

    if (character === "\\" && quote === '"') {
      if (index + 1 < value.length) {
        const nextCharacter = value.charAt(index + 1);
        current += nextCharacter;
        index += 1;
        continue;
      }
    }

    current += character;
  }

  pushCurrent();
  return tokens;
}

export function resolveLogMode(rawChezMoiArgs: string): LogMode {
  const { values } = parseArgs({
    args: tokenizeShellWords(rawChezMoiArgs),
    options: {
      verbose: { type: "boolean", short: "v", default: false },
      debug: { type: "boolean", default: false },
    },
    strict: false,
    allowPositionals: true,
  });

  return values.debug ? "debug" : values.verbose ? "verbose" : "info";
}

function createPlatformConfigs(
  sourceStateRoot: string,
  hostHome: string,
): Record<PlatformKind, PlatformConfig> {
  return {
    unix: {
      kind: "unix",
      wrapperRoot: path.join(sourceStateRoot, "dot_config", "nvim"),
      targetPrefix: path.posix.join(".config", "nvim"),
      targetRoot: path.join(hostHome, ".config", "nvim"),
    },
    windows: {
      kind: "windows",
      wrapperRoot: path.join(sourceStateRoot, "AppData", "Local", "nvim"),
      targetPrefix: path.posix.join("AppData", "Local", "nvim"),
      targetRoot: path.join(hostHome, "AppData", "Local", "nvim"),
    },
  };
}

function formatTimestamp(date: Date = new Date()): string {
  const pad = (value: number): string => value.toString().padStart(2, "0");

  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
  ].join("-") +
    ` ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function shouldLog(logMode: LogMode, level: LogLevel): boolean {
  const modeRank: Record<LogMode, number> = {
    info: 1,
    verbose: 2,
    debug: 3,
  };
  const levelRank: Record<Exclude<LogLevel, "ERROR">, number> = {
    INFO: 1,
    VERBOSE: 2,
    DEBUG: 3,
  };

  if (level === "ERROR") {
    return true;
  }

  return modeRank[logMode] >= levelRank[level];
}

function createLogger(logMode: LogMode, writers: LogWriters): Logger {
  function write(level: LogLevel, message: string): void {
    if (!shouldLog(logMode, level)) {
      return;
    }

    const line = `[${formatTimestamp(writers.now())}] ${level}: ${LOG_PREFIX} ${message}\n`;
    const writer = level === "ERROR" ? writers.stderr : writers.stdout;
    writer(line);
  }

  return {
    error: (message) => write("ERROR", message),
    info: (message) => write("INFO", message),
    verbose: (message) => write("VERBOSE", message),
    debug: (message) => write("DEBUG", message),
  };
}

function createRuntime(options: ReconcileNvimOptions = {}): ReconcileRuntime {
  const repoRoot = options.repoRoot ?? defaultRepoRoot;
  const sourceStateRoot = options.sourceStateRoot ?? path.join(repoRoot, "home");
  const hostHome = options.hostHome ?? os.homedir();
  const hostKind = options.hostKind ?? defaultHostKind;
  const logMode = options.logMode ?? resolveLogMode(process.env.CHEZMOI_ARGS ?? "");
  const platformConfigs = createPlatformConfigs(sourceStateRoot, hostHome);
  const hostPlatform = platformConfigs[hostKind];
  const writers: LogWriters = {
    stdout: options.stdout ?? ((line) => process.stdout.write(line)),
    stderr: options.stderr ?? ((line) => process.stderr.write(line)),
    now: options.now ?? (() => new Date()),
  };

  if (hostPlatform === undefined) {
    throw new Error(`unsupported host platform: ${hostKind}`);
  }

  return {
    hostKind,
    hostHome,
    hostPlatform,
    logMode,
    platforms: Object.values(platformConfigs),
    platformConfigs,
    rawRoot: options.rawRoot ?? path.join(sourceStateRoot, ".shared-configs", "nvim"),
    removeManifestPath:
      options.removeManifestPath ?? path.join(sourceStateRoot, ".chezmoiremove"),
    repoRoot,
    logger: createLogger(logMode, writers),
  };
}

function toPosixPath(value: string): string {
  return value.split(path.sep).join(path.posix.sep);
}

function fromPosixPath(value: string): string {
  return value.split(path.posix.sep).join(path.sep);
}

function displayRepoPath(runtime: ReconcileRuntime, targetPath: string): string {
  return toPosixPath(path.relative(runtime.repoRoot, targetPath));
}

function displayRawSourcePath(runtime: ReconcileRuntime, relativePath: string): string {
  const displayRoot = toPosixPath(path.relative(runtime.repoRoot, runtime.rawRoot));
  return path.posix.join(displayRoot, relativePath);
}

function targetPathFor(platform: PlatformConfig, relativePath: string): string {
  return path.posix.join(platform.targetPrefix, relativePath);
}

function absoluteTargetPath(runtime: ReconcileRuntime, entry: string): string {
  return path.join(runtime.hostHome, fromPosixPath(entry));
}

function wrapperContent(relativePath: string): string {
  // `include` resolves from the chezmoi source-state root (`home/` via `.chezmoiroot`),
  // so wrapper paths must stay POSIX-style and source-relative.
  const includePath = path.posix.join(".shared-configs", "nvim", relativePath);
  return `{{- include "${includePath}" -}}`;
}

function expectedWrapperFor(
  platform: PlatformConfig,
  relativePath: string,
): ExpectedWrapper {
  const relativeFsPath = fromPosixPath(relativePath);

  return {
    platform,
    relativePath,
    wrapperPath: path.join(platform.wrapperRoot, relativeFsPath) + ".tmpl",
    content: wrapperContent(relativePath),
  };
}

function wrapperTargetPath(
  platform: PlatformConfig,
  wrapperPath: string,
): string {
  const relativeWrapperPath = toPosixPath(path.relative(platform.wrapperRoot, wrapperPath));
  const relativeTargetPath = relativeWrapperPath.replace(/\.tmpl$/, "");
  return targetPathFor(platform, relativeTargetPath);
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function scanFiles(glob: Glob, rootDir: string): Promise<string[]> {
  if (!(await pathExists(rootDir))) {
    return [];
  }

  const filePaths: string[] = [];

  for await (const filePath of glob.scan({
    cwd: rootDir,
    dot: true,
    absolute: true,
    onlyFiles: true,
  })) {
    filePaths.push(filePath);
  }

  filePaths.sort((left, right) => left.localeCompare(right));
  return filePaths;
}

async function listRawRelativePaths(rootDir: string): Promise<string[]> {
  const filePaths = await scanFiles(allFilesGlob, rootDir);

  return filePaths
    .filter((filePath) => !path.basename(filePath).startsWith("."))
    .map((filePath) => toPosixPath(path.relative(rootDir, filePath)))
    .sort((left, right) => left.localeCompare(right));
}

async function listExistingWrappers(
  platform: PlatformConfig,
): Promise<ExistingWrapper[]> {
  const filePaths = await scanFiles(wrapperFilesGlob, platform.wrapperRoot);
  return filePaths.map((wrapperPath) => ({ platform, wrapperPath }));
}

async function readFileIfExists(targetPath: string): Promise<string | null> {
  try {
    return await fs.readFile(targetPath, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      throw error;
    }

    return null;
  }
}

async function writeTextFile(targetPath: string, content: string): Promise<void> {
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
  await fs.writeFile(targetPath, content, "utf8");
}

async function ensureWrapper(
  runtime: ReconcileRuntime,
  expectedWrapper: ExpectedWrapper,
): Promise<boolean> {
  const currentContent = await readFileIfExists(expectedWrapper.wrapperPath);

  if (currentContent === expectedWrapper.content) {
    return false;
  }

  await writeTextFile(expectedWrapper.wrapperPath, expectedWrapper.content);

  if (currentContent === null) {
    runtime.logger.debug(
      `Adding wrapper: ${displayRawSourcePath(runtime, expectedWrapper.relativePath)} -> ${displayRepoPath(runtime, expectedWrapper.wrapperPath)}`,
    );
    return true;
  }

  return false;
}

async function writeFileIfChanged(targetPath: string, content: string): Promise<boolean> {
  const currentContent = await readFileIfExists(targetPath);

  if (currentContent === content) {
    return false;
  }

  await writeTextFile(targetPath, content);
  return true;
}

async function pruneEmptyDirectories(rootDir: string): Promise<void> {
  if (!(await pathExists(rootDir))) {
    return;
  }

  async function prune(currentDir: string): Promise<void> {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });

    for (const entry of entries) {
      if (entry.isDirectory()) {
        await prune(path.join(currentDir, entry.name));
      }
    }

    const remainingEntries = await fs.readdir(currentDir);
    if (currentDir !== rootDir && remainingEntries.length === 0) {
      await fs.rmdir(currentDir);
    }
  }

  await prune(rootDir);
}

async function readExistingRemoveEntries(runtime: ReconcileRuntime): Promise<string[]> {
  if (!(await pathExists(runtime.removeManifestPath))) {
    return [];
  }

  const content = await fs.readFile(runtime.removeManifestPath, "utf8");

  return content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith("#"));
}

function hostExpectedTargets(runtime: ReconcileRuntime, relativePaths: string[]): Set<string> {
  return new Set(
    relativePaths.map((relativePath) => targetPathFor(runtime.hostPlatform, relativePath)),
  );
}

async function shouldKeepHostRemovalEntry(
  runtime: ReconcileRuntime,
  entry: string,
  expectedTargets: Set<string>,
): Promise<boolean> {
  // Preserve only stale entries for the current host. Unix runs should not retain
  // Windows removals, and vice versa.
  if (!entry.startsWith(`${runtime.hostPlatform.targetPrefix}/`)) {
    return false;
  }

  if (expectedTargets.has(entry)) {
    return false;
  }

  return pathExists(absoluteTargetPath(runtime, entry));
}

async function removeStaleWrappers(
  runtime: ReconcileRuntime,
  staleWrappers: ExistingWrapper[],
): Promise<void> {
  if (staleWrappers.length === 0) {
    return;
  }

  runtime.logger.debug(`Removing ${staleWrappers.length} stale wrapper(s)`);

  for (const { platform, wrapperPath } of staleWrappers) {
    runtime.logger.debug(
      `Removing stale wrapper: ${displayRepoPath(runtime, wrapperPath)} -> ${wrapperTargetPath(platform, wrapperPath)}`,
    );
    await fs.rm(wrapperPath);
  }
}

async function addMissingWrappers(
  runtime: ReconcileRuntime,
  expectedWrappers: ExpectedWrapper[],
): Promise<void> {
  for (const expectedWrapper of expectedWrappers) {
    await ensureWrapper(runtime, expectedWrapper);
  }
}

function groupExpectedWrappersByRawPath(
  expectedWrappers: ExpectedWrapper[],
): Map<string, ExpectedWrapper[]> {
  const grouped = new Map<string, ExpectedWrapper[]>();

  for (const expectedWrapper of expectedWrappers) {
    const current = grouped.get(expectedWrapper.relativePath) ?? [];
    current.push(expectedWrapper);
    grouped.set(expectedWrapper.relativePath, current);
  }

  return grouped;
}

function addedRawRelativePaths(
  expectedWrappers: ExpectedWrapper[],
  existingWrapperPaths: Set<string>,
): string[] {
  return Array.from(groupExpectedWrappersByRawPath(expectedWrappers).entries())
    .filter(([, wrappers]) =>
      wrappers.every((expectedWrapper) => !existingWrapperPaths.has(expectedWrapper.wrapperPath)),
    )
    .map(([relativePath]) => relativePath)
    .sort((left, right) => left.localeCompare(right));
}

function removedRawRelativePaths(staleWrappers: ExistingWrapper[]): string[] {
  const removed = new Set<string>();

  for (const { platform, wrapperPath } of staleWrappers) {
    const targetPath = wrapperTargetPath(platform, wrapperPath);
    removed.add(targetPath.slice(`${platform.targetPrefix}/`.length));
  }

  return Array.from(removed).sort((left, right) => left.localeCompare(right));
}

async function writeRemoveManifest(
  runtime: ReconcileRuntime,
  removeEntries: Set<string>,
): Promise<void> {
  const sortedRemoveEntries = Array.from(removeEntries).sort((left, right) =>
    left.localeCompare(right),
  );
  const content =
    sortedRemoveEntries.length > 0 ? `${sortedRemoveEntries.join("\n")}\n` : "";

  const updated = await writeFileIfChanged(runtime.removeManifestPath, content);

  if (updated) {
    runtime.logger.debug(`Updated remove manifest: ${runtime.removeManifestPath}`);
  }
}

function hostRemoveEntries(
  runtime: ReconcileRuntime,
  staleWrappers: ExistingWrapper[],
): Set<string> {
  return new Set(
    staleWrappers
      .filter(({ platform }) => platform.kind === runtime.hostKind)
      .map(({ platform, wrapperPath }) => wrapperTargetPath(platform, wrapperPath)),
  );
}

export async function reconcileNvimConfig(
  options: ReconcileNvimOptions = {},
): Promise<ReconcileSummary> {
  const runtime = createRuntime(options);

  runtime.logger.debug(
    `Configuration loaded: host=${runtime.hostKind} log_mode=${runtime.logMode}`,
  );
  runtime.logger.debug(`Canonical raw root: ${runtime.rawRoot}`);
  runtime.logger.debug(`Unix wrapper root: ${runtime.platformConfigs.unix.wrapperRoot}`);
  runtime.logger.debug(
    `Windows wrapper root: ${runtime.platformConfigs.windows.wrapperRoot}`,
  );
  runtime.logger.debug(`Host target root: ${runtime.hostPlatform.targetRoot}`);
  runtime.logger.debug(`Remove manifest: ${runtime.removeManifestPath}`);

  if (!(await pathExists(runtime.rawRoot))) {
    throw new Error(`canonical raw Neovim tree not found: ${runtime.rawRoot}`);
  }

  const rawRelativePaths = await listRawRelativePaths(runtime.rawRoot);
  const expectedWrappers = rawRelativePaths.flatMap((relativePath) =>
    runtime.platforms.map((platform) => expectedWrapperFor(platform, relativePath)),
  );
  const expectedWrapperPaths = new Set(
    expectedWrappers.map((expectedWrapper) => expectedWrapper.wrapperPath),
  );

  const existingWrappers = (
    await Promise.all(runtime.platforms.map((platform) => listExistingWrappers(platform)))
  ).flat();
  const existingWrapperPaths = new Set(
    existingWrappers.map(({ wrapperPath }) => wrapperPath),
  );

  const staleWrappers = existingWrappers.filter(
    ({ wrapperPath }) => !expectedWrapperPaths.has(wrapperPath),
  );
  const addedRawPaths = addedRawRelativePaths(expectedWrappers, existingWrapperPaths);
  const removedRawPaths = removedRawRelativePaths(staleWrappers);

  runtime.logger.verbose(`Scanned ${rawRelativePaths.length} raw Neovim file(s)`);
  for (const relativePath of addedRawPaths) {
    runtime.logger.verbose(`Added raw file: ${displayRawSourcePath(runtime, relativePath)}`);
  }
  for (const relativePath of removedRawPaths) {
    runtime.logger.verbose(`Removed raw file: ${displayRawSourcePath(runtime, relativePath)}`);
  }

  // Removing a source wrapper is not enough for chezmoi to remove the already-applied
  // target file, so stale wrappers are translated into `.chezmoiremove` entries.
  const removeEntries = hostRemoveEntries(runtime, staleWrappers);

  await removeStaleWrappers(runtime, staleWrappers);

  for (const platform of runtime.platforms) {
    await pruneEmptyDirectories(platform.wrapperRoot);
  }

  await addMissingWrappers(runtime, expectedWrappers);
  const expectedTargets = hostExpectedTargets(runtime, rawRelativePaths);

  const previousRemoveEntries = await readExistingRemoveEntries(runtime);
  for (const entry of previousRemoveEntries) {
    if (await shouldKeepHostRemovalEntry(runtime, entry, expectedTargets)) {
      removeEntries.add(entry);
    }
  }

  await writeRemoveManifest(runtime, removeEntries);

  const summary: ReconcileSummary = {
    raw: rawRelativePaths.length,
    added: addedRawPaths.length,
    removed: removedRawPaths.length,
    host: runtime.hostKind,
    targetRoot: runtime.hostPlatform.targetRoot,
  };

  runtime.logger.info(
    [
      `raw=${summary.raw}`,
      `added=${summary.added}`,
      `removed=${summary.removed}`,
      `host=${summary.host}`,
      `target_root=${summary.targetRoot}`,
    ].join(" "),
  );

  return summary;
}

function writeFallbackError(
  message: string,
  stderr: (line: string) => void,
  now: () => Date,
): void {
  stderr(`[${formatTimestamp(now())}] ERROR: ${LOG_PREFIX} ${message}\n`);
}

export async function runCli(options: RunCliOptions = {}): Promise<void> {
  const { exit = (code: number) => process.exit(code), ...reconcileOptions } = options;

  try {
    await reconcileNvimConfig(reconcileOptions);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.stack ?? error.message : String(error);
    writeFallbackError(
      message,
      reconcileOptions.stderr ?? ((line) => process.stderr.write(line)),
      reconcileOptions.now ?? (() => new Date()),
    );
    exit(1);
  }
}

export async function main(): Promise<void> {
  await runCli();
}

if (import.meta.main) {
  await main();
}
