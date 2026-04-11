import { Glob } from "bun";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";

import { type ToolConfig, tools as defaultTools, validateToolRegistry } from "./tools.config.ts";

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
  logPrefix: string;
  platforms: PlatformConfig[];
  platformConfigs: Record<PlatformKind, PlatformConfig>;
  rawRoot: string;
  removeManifestPath: string;
  repoRoot: string;
  tool: ToolConfig;
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

export type ReconcileOptions = {
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
  toolName: string;
};

export type ReconcileAllSummary = {
  tools: ReconcileSummary[];
};

export type RunCliOptions = ReconcileOptions & {
  exit?: (code: number) => void;
};

const allFilesGlob = new Glob("**/*");
const wrapperFilesGlob = new Glob("**/*.tmpl");
const defaultRepoRoot = path.resolve(import.meta.dir, "..");
const defaultHostKind: PlatformKind = process.platform === "win32" ? "windows" : "unix";

export function tokenizeShellWords(value: string): string[] {
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
  tool: ToolConfig,
  sourceStateRoot: string,
  hostHome: string,
): Record<PlatformKind, PlatformConfig> {
  return {
    unix: {
      kind: "unix",
      wrapperRoot: path.join(sourceStateRoot, ...tool.targets.unix.wrapperRoot.split("/")),
      targetPrefix: tool.targets.unix.targetPrefix,
      targetRoot: path.join(hostHome, ...tool.targets.unix.targetPrefix.split("/")),
    },
    windows: {
      kind: "windows",
      wrapperRoot: path.join(sourceStateRoot, ...tool.targets.windows.wrapperRoot.split("/")),
      targetPrefix: tool.targets.windows.targetPrefix,
      targetRoot: path.join(hostHome, ...tool.targets.windows.targetPrefix.split("/")),
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

function createLogger(logPrefix: string, logMode: LogMode, writers: LogWriters): Logger {
  function write(level: LogLevel, message: string): void {
    if (!shouldLog(logMode, level)) {
      return;
    }

    const line = `[${formatTimestamp(writers.now())}] ${level}: ${logPrefix} ${message}\n`;
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

function createRuntime(tool: ToolConfig, options: ReconcileOptions = {}): ReconcileRuntime {
  const repoRoot = options.repoRoot ?? defaultRepoRoot;
  const sourceStateRoot = options.sourceStateRoot ?? path.join(repoRoot, "home");
  const hostHome = options.hostHome ?? os.homedir();
  const hostKind = options.hostKind ?? defaultHostKind;
  const logMode = options.logMode ?? resolveLogMode(process.env.CHEZMOI_ARGS ?? "");
  const platformConfigs = createPlatformConfigs(tool, sourceStateRoot, hostHome);
  const hostPlatform = platformConfigs[hostKind];
  const logPrefix = `[reconcile-configs/${tool.name}]`;
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
    logPrefix,
    platforms: Object.values(platformConfigs),
    platformConfigs,
    rawRoot: options.rawRoot ?? path.join(sourceStateRoot, ...tool.source.split("/")),
    removeManifestPath:
      options.removeManifestPath ?? path.join(sourceStateRoot, ".chezmoiremove"),
    repoRoot,
    tool,
    logger: createLogger(logPrefix, logMode, writers),
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

function wrapperContent(toolSource: string, relativePath: string): string {
  const includePath = path.posix.join(toolSource, relativePath);
  return `{{- include "${includePath}" -}}`;
}

function expectedWrapperFor(
  platform: PlatformConfig,
  toolSource: string,
  relativePath: string,
): ExpectedWrapper {
  const relativeFsPath = fromPosixPath(relativePath);

  return {
    platform,
    relativePath,
    wrapperPath: path.join(platform.wrapperRoot, relativeFsPath) + ".tmpl",
    content: wrapperContent(toolSource, relativePath),
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

async function readExistingRemoveEntries(removeManifestPath: string): Promise<string[]> {
  if (!(await pathExists(removeManifestPath))) {
    return [];
  }

  const content = await fs.readFile(removeManifestPath, "utf8");

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
  removeManifestPath: string,
  removeEntries: Set<string>,
  logger: Logger,
): Promise<void> {
  const sortedRemoveEntries = Array.from(removeEntries).sort((left, right) =>
    left.localeCompare(right),
  );
  const content =
    sortedRemoveEntries.length > 0 ? `${sortedRemoveEntries.join("\n")}\n` : "";

  const updated = await writeFileIfChanged(removeManifestPath, content);

  if (updated) {
    logger.debug(`Updated remove manifest: ${removeManifestPath}`);
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

/** @internal Core reconciliation logic for a single tool, returns summary and removal entries without writing the manifest. */
async function reconcileToolCore(
  tool: ToolConfig,
  options: ReconcileOptions,
): Promise<{ summary: ReconcileSummary; removeEntries: Set<string> }> {
  const runtime = createRuntime(tool, options);

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
    throw new Error(`canonical raw tree not found for tool "${tool.name}": ${runtime.rawRoot}`);
  }

  const rawRelativePaths = await listRawRelativePaths(runtime.rawRoot);
  const expectedWrappers = rawRelativePaths.flatMap((relativePath) =>
    runtime.platforms.map((platform) =>
      expectedWrapperFor(platform, tool.source, relativePath),
    ),
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

  runtime.logger.verbose(`Scanned ${rawRelativePaths.length} raw ${tool.name} file(s)`);
  for (const relativePath of addedRawPaths) {
    runtime.logger.verbose(`Added raw file: ${displayRawSourcePath(runtime, relativePath)}`);
  }
  for (const relativePath of removedRawPaths) {
    runtime.logger.verbose(`Removed raw file: ${displayRawSourcePath(runtime, relativePath)}`);
  }

  const removeEntries = hostRemoveEntries(runtime, staleWrappers);

  await removeStaleWrappers(runtime, staleWrappers);

  for (const platform of runtime.platforms) {
    await pruneEmptyDirectories(platform.wrapperRoot);
  }

  await addMissingWrappers(runtime, expectedWrappers);

  const expectedTargets = hostExpectedTargets(runtime, rawRelativePaths);

  const previousRemoveEntries = await readExistingRemoveEntries(runtime.removeManifestPath);
  for (const entry of previousRemoveEntries) {
    if (await shouldKeepHostRemovalEntry(runtime, entry, expectedTargets)) {
      removeEntries.add(entry);
    }
  }

  const summary: ReconcileSummary = {
    raw: rawRelativePaths.length,
    added: addedRawPaths.length,
    removed: removedRawPaths.length,
    host: runtime.hostKind,
    targetRoot: runtime.hostPlatform.targetRoot,
    toolName: tool.name,
  };

  runtime.logger.info(
    [
      `tool=${summary.toolName}`,
      `raw=${summary.raw}`,
      `added=${summary.added}`,
      `removed=${summary.removed}`,
      `host=${summary.host}`,
      `target_root=${summary.targetRoot}`,
    ].join(" "),
  );

  return { summary, removeEntries };
}

export async function reconcileTool(
  tool: ToolConfig,
  options: ReconcileOptions = {},
): Promise<ReconcileSummary> {
  const { summary, removeEntries } = await reconcileToolCore(tool, options);

  const runtime = createRuntime(tool, options);
  await writeRemoveManifest(runtime.removeManifestPath, removeEntries, runtime.logger);

  return summary;
}

export async function reconcileAllTools(
  options: ReconcileOptions = {},
  toolList: ToolConfig[] = defaultTools,
): Promise<ReconcileAllSummary> {
  validateToolRegistry(toolList);

  const summaries: ReconcileSummary[] = [];
  const allRemoveEntries = new Set<string>();

  for (const tool of toolList) {
    const { summary, removeEntries } = await reconcileToolCore(tool, options);
    summaries.push(summary);

    for (const entry of removeEntries) {
      allRemoveEntries.add(entry);
    }
  }

  const repoRoot = options.repoRoot ?? defaultRepoRoot;
  const sourceStateRoot = options.sourceStateRoot ?? path.join(repoRoot, "home");
  const removeManifestPath = options.removeManifestPath ?? path.join(sourceStateRoot, ".chezmoiremove");
  const logMode = options.logMode ?? resolveLogMode(process.env.CHEZMOI_ARGS ?? "");
  const writers: LogWriters = {
    stdout: options.stdout ?? ((line) => process.stdout.write(line)),
    stderr: options.stderr ?? ((line) => process.stderr.write(line)),
    now: options.now ?? (() => new Date()),
  };
  await writeRemoveManifest(removeManifestPath, allRemoveEntries, createLogger("[reconcile-configs]", logMode, writers));

  return { tools: summaries };
}

function writeFallbackError(
  message: string,
  logPrefix: string,
  stderr: (line: string) => void,
  now: () => Date,
): void {
  stderr(`[${formatTimestamp(now())}] ERROR: ${logPrefix} ${message}\n`);
}

export async function runCli(options: RunCliOptions = {}): Promise<void> {
  const { exit = (code: number) => process.exit(code), ...reconcileOptions } = options;
  const logPrefix = "[reconcile-configs]";

  try {
    await reconcileAllTools(reconcileOptions);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.stack ?? error.message : String(error);
    writeFallbackError(
      message,
      logPrefix,
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
