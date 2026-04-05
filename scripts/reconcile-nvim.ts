import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

type HostKind = "unix" | "windows";

const scriptPath = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptPath);
const repoRoot = path.resolve(scriptDir, "..");
const sourceStateRoot = path.join(repoRoot, "home");
const rawRoot = path.join(sourceStateRoot, ".shared-configs", "nvim");
const unixWrapperRoot = path.join(sourceStateRoot, "dot_config", "nvim");
const windowsWrapperRoot = path.join(sourceStateRoot, "AppData", "Local", "nvim");
const removeManifestPath = path.join(sourceStateRoot, ".chezmoiremove");

const hostKind: HostKind = process.platform === "win32" ? "windows" : "unix";
const hostManifestPrefix =
  hostKind === "windows" ? "AppData/Local/nvim" : ".config/nvim";
const hostTargetRoot =
  hostKind === "windows"
    ? path.join(os.homedir(), "AppData", "Local", "nvim")
    : path.join(os.homedir(), ".config", "nvim");

function toPosixPath(value: string): string {
  return value.split(path.sep).join(path.posix.sep);
}

function fromPosixPath(value: string): string {
  return value.split(path.posix.sep).join(path.sep);
}

function unixTargetPath(relativePath: string): string {
  return path.posix.join(".config", "nvim", relativePath);
}

function windowsTargetPath(relativePath: string): string {
  return path.posix.join("AppData", "Local", "nvim", relativePath);
}

function wrapperContent(relativePath: string): string {
  const includePath = path.posix.join(".shared-configs", "nvim", relativePath);
  return `{{- include "${includePath}" -}}`;
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
  const results: string[] = [];

  if (!(await pathExists(rootDir))) {
    return results;
  }

  async function walk(currentDir: string): Promise<void> {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name));

    for (const entry of entries) {
      const entryPath = path.join(currentDir, entry.name);

      if (entry.isDirectory()) {
        await walk(entryPath);
        continue;
      }

      if (!entry.isFile()) {
        continue;
      }

      results.push(entryPath);
    }
  }

  await walk(rootDir);
  results.sort((left, right) => left.localeCompare(right));
  return results;
}

async function listRawFiles(rootDir: string): Promise<string[]> {
  const filePaths = await listFilesRecursive(rootDir);

  return filePaths
    .filter((filePath) => !path.basename(filePath).startsWith("."))
    .map((filePath) => toPosixPath(path.relative(rootDir, filePath)))
    .sort((left, right) => left.localeCompare(right));
}

async function listWrapperFiles(rootDir: string): Promise<string[]> {
  const filePaths = await listFilesRecursive(rootDir);
  return filePaths
    .filter((filePath) => filePath.endsWith(".tmpl"))
    .sort((left, right) => left.localeCompare(right));
}

async function writeFileIfChanged(targetPath: string, content: string): Promise<boolean> {
  let currentContent: string | null = null;

  try {
    currentContent = await fs.readFile(targetPath, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      throw error;
    }
  }

  if (currentContent === content) {
    return false;
  }

  await fs.mkdir(path.dirname(targetPath), { recursive: true });
  await fs.writeFile(targetPath, content, "utf8");
  return true;
}

async function pruneEmptyDirectories(rootDir: string): Promise<void> {
  if (!(await pathExists(rootDir))) {
    return;
  }

  async function prune(currentDir: string): Promise<boolean> {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });

    for (const entry of entries) {
      if (!entry.isDirectory()) {
        continue;
      }

      await prune(path.join(currentDir, entry.name));
    }

    const remainingEntries = await fs.readdir(currentDir);
    if (currentDir !== rootDir && remainingEntries.length === 0) {
      await fs.rmdir(currentDir);
      return true;
    }

    return false;
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

function manifestEntryToAbsoluteTarget(entry: string): string {
  return path.join(os.homedir(), fromPosixPath(entry));
}

function buildHostExpectedTargets(relativePaths: string[]): Set<string> {
  const mapper = hostKind === "windows" ? windowsTargetPath : unixTargetPath;
  return new Set(relativePaths.map((relativePath) => mapper(relativePath)));
}

function wrapperToTargetPath(wrapperRoot: string, wrapperPath: string): string {
  const relativeWrapperPath = toPosixPath(path.relative(wrapperRoot, wrapperPath));
  const relativeTargetPath = relativeWrapperPath.replace(/\.tmpl$/, "");

  if (wrapperRoot === unixWrapperRoot) {
    return unixTargetPath(relativeTargetPath);
  }

  return windowsTargetPath(relativeTargetPath);
}

async function keepHostRemovalEntry(
  entry: string,
  expectedHostTargets: Set<string>,
): Promise<boolean> {
  if (!entry.startsWith(`${hostManifestPrefix}/`)) {
    return false;
  }

  if (expectedHostTargets.has(entry)) {
    return false;
  }

  return pathExists(manifestEntryToAbsoluteTarget(entry));
}

async function reconcile(): Promise<void> {
  if (!(await pathExists(rawRoot))) {
    throw new Error(`canonical raw Neovim tree not found: ${rawRoot}`);
  }

  const rawRelativePaths = await listRawFiles(rawRoot);
  const expectedHostTargets = buildHostExpectedTargets(rawRelativePaths);

  const expectedUnixWrappers = new Map<string, string>();
  const expectedWindowsWrappers = new Map<string, string>();

  for (const relativePath of rawRelativePaths) {
    const relativeFsPath = fromPosixPath(relativePath);
    expectedUnixWrappers.set(
      path.join(unixWrapperRoot, relativeFsPath) + ".tmpl",
      wrapperContent(relativePath),
    );
    expectedWindowsWrappers.set(
      path.join(windowsWrapperRoot, relativeFsPath) + ".tmpl",
      wrapperContent(relativePath),
    );
  }

  const existingUnixWrappers = await listWrapperFiles(unixWrapperRoot);
  const existingWindowsWrappers = await listWrapperFiles(windowsWrapperRoot);

  const staleWrapperPaths = [
    ...existingUnixWrappers.filter((wrapperPath) => !expectedUnixWrappers.has(wrapperPath)),
    ...existingWindowsWrappers.filter((wrapperPath) => !expectedWindowsWrappers.has(wrapperPath)),
  ];

  const removeEntries = new Set<string>(
    staleWrapperPaths.map((wrapperPath) => {
      const wrapperRoot = wrapperPath.startsWith(unixWrapperRoot)
        ? unixWrapperRoot
        : windowsWrapperRoot;
      return wrapperToTargetPath(wrapperRoot, wrapperPath);
    }),
  );

  for (const wrapperPath of staleWrapperPaths) {
    await fs.rm(wrapperPath);
  }

  await pruneEmptyDirectories(unixWrapperRoot);
  await pruneEmptyDirectories(windowsWrapperRoot);

  let wrappersWritten = 0;

  for (const [wrapperPath, content] of expectedUnixWrappers) {
    if (await writeFileIfChanged(wrapperPath, content)) {
      wrappersWritten += 1;
    }
  }

  for (const [wrapperPath, content] of expectedWindowsWrappers) {
    if (await writeFileIfChanged(wrapperPath, content)) {
      wrappersWritten += 1;
    }
  }

  const previousRemoveEntries = await readExistingRemoveEntries();
  for (const entry of previousRemoveEntries) {
    if (await keepHostRemovalEntry(entry, expectedHostTargets)) {
      removeEntries.add(entry);
    }
  }

  const sortedRemoveEntries = Array.from(removeEntries).sort((left, right) =>
    left.localeCompare(right),
  );
  const removeManifestContent =
    sortedRemoveEntries.length > 0 ? `${sortedRemoveEntries.join("\n")}\n` : "";
  const removeManifestUpdated = await writeFileIfChanged(
    removeManifestPath,
    removeManifestContent,
  );

  console.error(
    [
      "[reconcile-nvim]",
      `raw=${rawRelativePaths.length}`,
      `written=${wrappersWritten}`,
      `stale_wrappers=${staleWrapperPaths.length}`,
      `remove_entries=${sortedRemoveEntries.length}`,
      `manifest_updated=${removeManifestUpdated ? "yes" : "no"}`,
      `host=${hostKind}`,
      `target_root=${hostTargetRoot}`,
    ].join(" "),
  );
}

await reconcile().catch((error: unknown) => {
  const message = error instanceof Error ? error.stack ?? error.message : String(error);
  console.error(`[reconcile-nvim] ERROR ${message}`);
  process.exit(1);
});
