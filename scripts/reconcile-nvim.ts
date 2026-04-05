import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

type LogLevel = "ERROR" | "WARN" | "INFO" | "DEBUG";
type PlatformId = "unix" | "windows";

type PlatformConfig = {
  id: PlatformId;
  wrapperRoot: string;
  targetPrefix: string;
  targetRoot: string;
};

type ExpectedWrapper = {
  platform: PlatformConfig;
  relativePath: string;
  wrapperPath: string;
  targetPath: string;
  content: string;
};

type ExistingWrapper = {
  platform: PlatformConfig;
  wrapperPath: string;
};

type WriteOutcome = "created" | "updated" | "unchanged";

const LOG_PREFIX = "[reconcile-nvim-config]";

const scriptPath = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptPath);
const repoRoot = path.resolve(scriptDir, "..");
const sourceStateRoot = path.join(repoRoot, "home");
const rawRoot = path.join(sourceStateRoot, ".shared-configs", "nvim");
const removeManifestPath = path.join(sourceStateRoot, ".chezmoiremove");

const hostKind: PlatformId = process.platform === "win32" ? "windows" : "unix";

const platforms: PlatformConfig[] = [
  {
    id: "unix",
    wrapperRoot: path.join(sourceStateRoot, "dot_config", "nvim"),
    targetPrefix: path.posix.join(".config", "nvim"),
    targetRoot: path.join(os.homedir(), ".config", "nvim"),
  },
  {
    id: "windows",
    wrapperRoot: path.join(sourceStateRoot, "AppData", "Local", "nvim"),
    targetPrefix: path.posix.join("AppData", "Local", "nvim"),
    targetRoot: path.join(os.homedir(), "AppData", "Local", "nvim"),
  },
];

function fail(message: string): never {
  throw new Error(message);
}

const hostPlatform =
  platforms.find((platform) => platform.id === hostKind) ??
  fail(`unsupported host platform: ${hostKind}`);

function parseChezMoiArgs(value: string): string[] {
  const tokens = value.match(/"[^"]*"|'[^']*'|\S+/g) ?? [];

  return tokens.map((token) =>
    token.startsWith('"') || token.startsWith("'") ? token.slice(1, -1) : token,
  );
}

const chezmoiArgs = parseChezMoiArgs(process.env.CHEZMOI_ARGS ?? "");
const verboseLoggingRequested = chezmoiArgs.some(
  (arg) => arg === "-v" || arg === "--verbose" || arg === "--debug",
);

function formatTimestamp(date: Date = new Date()): string {
  const pad = (value: number): string => value.toString().padStart(2, "0");

  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
  ].join("-") +
    ` ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function shouldLog(level: LogLevel): boolean {
  if (verboseLoggingRequested) {
    return true;
  }

  return level !== "DEBUG";
}

function writeLog(level: LogLevel, message: string): void {
  if (!shouldLog(level)) {
    return;
  }

  const line = `[${formatTimestamp()}] ${level}: ${LOG_PREFIX} ${message}\n`;
  const stream =
    level === "ERROR" || level === "WARN" ? process.stderr : process.stdout;
  stream.write(line);
}

function logError(message: string): void {
  writeLog("ERROR", message);
}

function logInfo(message: string): void {
  writeLog("INFO", message);
}

function logDebug(message: string): void {
  writeLog("DEBUG", message);
}

function toPosixPath(value: string): string {
  return value.split(path.sep).join(path.posix.sep);
}

function fromPosixPath(value: string): string {
  return value.split(path.posix.sep).join(path.sep);
}

function displayRepoPath(targetPath: string): string {
  return toPosixPath(path.relative(repoRoot, targetPath));
}

function displayRawSourcePath(relativePath: string): string {
  return path.posix.join("home", ".shared-configs", "nvim", relativePath);
}

function targetPathFor(platform: PlatformConfig, relativePath: string): string {
  return path.posix.join(platform.targetPrefix, relativePath);
}

function absoluteTargetPath(entry: string): string {
  return path.join(os.homedir(), fromPosixPath(entry));
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
    targetPath: targetPathFor(platform, relativePath),
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

async function listFilesRecursive(rootDir: string): Promise<string[]> {
  if (!(await pathExists(rootDir))) {
    return [];
  }

  const results: string[] = [];

  async function walk(currentDir: string): Promise<void> {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name));

    for (const entry of entries) {
      const entryPath = path.join(currentDir, entry.name);

      if (entry.isDirectory()) {
        await walk(entryPath);
        continue;
      }

      if (entry.isFile()) {
        results.push(entryPath);
      }
    }
  }

  await walk(rootDir);
  results.sort((left, right) => left.localeCompare(right));
  return results;
}

async function listRawRelativePaths(rootDir: string): Promise<string[]> {
  const filePaths = await listFilesRecursive(rootDir);

  return filePaths
    .filter((filePath) => !path.basename(filePath).startsWith("."))
    .map((filePath) => toPosixPath(path.relative(rootDir, filePath)))
    .sort((left, right) => left.localeCompare(right));
}

async function listExistingWrappers(
  platform: PlatformConfig,
): Promise<ExistingWrapper[]> {
  const filePaths = await listFilesRecursive(platform.wrapperRoot);

  return filePaths
    .filter((filePath) => filePath.endsWith(".tmpl"))
    .sort((left, right) => left.localeCompare(right))
    .map((wrapperPath) => ({ platform, wrapperPath }));
}

async function writeFile(targetPath: string, content: string): Promise<WriteOutcome> {
  let currentContent: string | null = null;
  let fileExists = true;

  try {
    currentContent = await fs.readFile(targetPath, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      throw error;
    }

    fileExists = false;
  }

  if (currentContent === content) {
    return "unchanged";
  }

  await fs.mkdir(path.dirname(targetPath), { recursive: true });
  await fs.writeFile(targetPath, content, "utf8");
  return fileExists ? "updated" : "created";
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

async function readExistingRemoveEntries(): Promise<string[]> {
  if (!(await pathExists(removeManifestPath))) {
    return [];
  }

  const content = await fs.readFile(removeManifestPath, "utf8");

  return content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith("#"));
}

function hostExpectedTargets(relativePaths: string[]): Set<string> {
  return new Set(relativePaths.map((relativePath) => targetPathFor(hostPlatform, relativePath)));
}

async function shouldKeepHostRemovalEntry(
  entry: string,
  expectedTargets: Set<string>,
): Promise<boolean> {
  // Preserve only stale entries for the current host. Unix runs should not retain
  // Windows removals, and vice versa.
  if (!entry.startsWith(`${hostPlatform.targetPrefix}/`)) {
    return false;
  }

  if (expectedTargets.has(entry)) {
    return false;
  }

  return pathExists(absoluteTargetPath(entry));
}

async function removeStaleWrappers(staleWrappers: ExistingWrapper[]): Promise<void> {
  if (staleWrappers.length === 0) {
    return;
  }

  logInfo(`Removing ${staleWrappers.length} stale wrapper(s)`);

  for (const { platform, wrapperPath } of staleWrappers) {
    logDebug(
      `Removing stale wrapper: ${displayRepoPath(wrapperPath)} -> ${wrapperTargetPath(platform, wrapperPath)}`,
    );
    await fs.rm(wrapperPath);
  }
}

async function writeExpectedWrappers(
  expectedWrappers: ExpectedWrapper[],
): Promise<{ created: number; updated: number }> {
  let created = 0;
  let updated = 0;

  for (const expectedWrapper of expectedWrappers) {
    const outcome = await writeFile(expectedWrapper.wrapperPath, expectedWrapper.content);

    if (outcome === "created") {
      created += 1;
      logDebug(
        `Creating wrapper: ${displayRawSourcePath(expectedWrapper.relativePath)} -> ${displayRepoPath(expectedWrapper.wrapperPath)}`,
      );
      continue;
    }

    if (outcome === "updated") {
      updated += 1;
      logDebug(
        `Updating wrapper: ${displayRawSourcePath(expectedWrapper.relativePath)} -> ${displayRepoPath(expectedWrapper.wrapperPath)}`,
      );
    }
  }

  return { created, updated };
}

async function writeRemoveManifest(removeEntries: Set<string>): Promise<boolean> {
  const sortedRemoveEntries = Array.from(removeEntries).sort((left, right) =>
    left.localeCompare(right),
  );
  const content =
    sortedRemoveEntries.length > 0 ? `${sortedRemoveEntries.join("\n")}\n` : "";

  const updated = (await writeFile(removeManifestPath, content)) !== "unchanged";

  if (updated) {
    logDebug(`Updated remove manifest: ${removeManifestPath}`);
  }

  return updated;
}

async function reconcile(): Promise<void> {
  logDebug(`Configuration loaded: host=${hostKind}`);
  logDebug(`Canonical raw root: ${rawRoot}`);
  logDebug(`Unix wrapper root: ${platforms[0]?.wrapperRoot ?? ""}`);
  logDebug(`Windows wrapper root: ${platforms[1]?.wrapperRoot ?? ""}`);
  logDebug(`Host target root: ${hostPlatform.targetRoot}`);
  logDebug(`Remove manifest: ${removeManifestPath}`);

  if (!(await pathExists(rawRoot))) {
    throw new Error(`canonical raw Neovim tree not found: ${rawRoot}`);
  }

  const rawRelativePaths = await listRawRelativePaths(rawRoot);
  logInfo(`Scanned ${rawRelativePaths.length} raw Neovim file(s)`);

  const expectedWrappers = rawRelativePaths.flatMap((relativePath) =>
    platforms.map((platform) => expectedWrapperFor(platform, relativePath)),
  );
  const expectedWrapperPaths = new Set(
    expectedWrappers.map((expectedWrapper) => expectedWrapper.wrapperPath),
  );

  const existingWrappers = (
    await Promise.all(platforms.map((platform) => listExistingWrappers(platform)))
  ).flat();

  const staleWrappers = existingWrappers.filter(
    ({ wrapperPath }) => !expectedWrapperPaths.has(wrapperPath),
  );

  // Removing a source wrapper is not enough for chezmoi to remove the already-applied
  // target file, so stale wrappers are translated into `.chezmoiremove` entries.
  const removeEntries = new Set(
    staleWrappers.map(({ platform, wrapperPath }) =>
      wrapperTargetPath(platform, wrapperPath),
    ),
  );

  await removeStaleWrappers(staleWrappers);

  for (const platform of platforms) {
    await pruneEmptyDirectories(platform.wrapperRoot);
  }

  const { created, updated } = await writeExpectedWrappers(expectedWrappers);
  const expectedTargets = hostExpectedTargets(rawRelativePaths);

  const previousRemoveEntries = await readExistingRemoveEntries();
  for (const entry of previousRemoveEntries) {
    if (await shouldKeepHostRemovalEntry(entry, expectedTargets)) {
      removeEntries.add(entry);
    }
  }

  const removeManifestUpdated = await writeRemoveManifest(removeEntries);

  logInfo(
    [
      `raw=${rawRelativePaths.length}`,
      `created=${created}`,
      `updated=${updated}`,
      `removed=${staleWrappers.length}`,
      `remove_entries=${removeEntries.size}`,
      `manifest_updated=${removeManifestUpdated ? "yes" : "no"}`,
      `host=${hostKind}`,
      `target_root=${hostPlatform.targetRoot}`,
    ].join(" "),
  );
}

await reconcile().catch((error: unknown) => {
  const message = error instanceof Error ? error.stack ?? error.message : String(error);
  logError(message);
  process.exit(1);
});
