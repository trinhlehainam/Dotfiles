import { afterEach, describe, expect, test } from "bun:test";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  reconcileNvimConfig,
  resolveLogMode,
  tokenizeShellWords,
  type LogMode,
  type PlatformKind,
} from "./reconcile-nvim.ts";

type TestWorkspace = {
  hostHome: string;
  rawRoot: string;
  removeManifestPath: string;
  repoRoot: string;
  sourceStateRoot: string;
  stderr: string[];
  stdout: string[];
  unixWrapperRoot: string;
  windowsWrapperRoot: string;
};

const tempDirs: string[] = [];

afterEach(async () => {
  await Promise.all(
    tempDirs.map((targetPath) => fs.rm(targetPath, { recursive: true, force: true })),
  );
  tempDirs.length = 0;
});

async function createWorkspace(): Promise<TestWorkspace> {
  const repoRoot = await fs.mkdtemp(path.join(os.tmpdir(), "reconcile-nvim-test-"));
  tempDirs.push(repoRoot);

  const sourceStateRoot = path.join(repoRoot, "home");
  const rawRoot = path.join(sourceStateRoot, ".shared-configs", "nvim");
  const hostHome = path.join(repoRoot, "host-home");

  await fs.mkdir(rawRoot, { recursive: true });
  await fs.mkdir(hostHome, { recursive: true });

  return {
    hostHome,
    rawRoot,
    removeManifestPath: path.join(sourceStateRoot, ".chezmoiremove"),
    repoRoot,
    sourceStateRoot,
    stderr: [],
    stdout: [],
    unixWrapperRoot: path.join(sourceStateRoot, "dot_config", "nvim"),
    windowsWrapperRoot: path.join(sourceStateRoot, "AppData", "Local", "nvim"),
  };
}

function makeRunOptions(
  workspace: TestWorkspace,
  overrides: Partial<{
    hostKind: PlatformKind;
    logMode: LogMode;
  }> = {},
) {
  workspace.stdout.length = 0;
  workspace.stderr.length = 0;

  return {
    hostHome: workspace.hostHome,
    hostKind: overrides.hostKind ?? "unix",
    logMode: overrides.logMode ?? "info",
    repoRoot: workspace.repoRoot,
    stderr: (line: string) => workspace.stderr.push(line),
    stdout: (line: string) => workspace.stdout.push(line),
  };
}

async function writeFile(targetPath: string, content: string): Promise<void> {
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
  await fs.writeFile(targetPath, content, "utf8");
}

async function readFile(targetPath: string): Promise<string> {
  return fs.readFile(targetPath, "utf8");
}

async function exists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

function wrapperTemplate(relativePath: string): string {
  return `{{- include ".shared-configs/nvim/${relativePath}" -}}`;
}

function unixWrapperPath(workspace: TestWorkspace, relativePath: string): string {
  return path.join(workspace.unixWrapperRoot, relativePath) + ".tmpl";
}

function windowsWrapperPath(workspace: TestWorkspace, relativePath: string): string {
  return path.join(workspace.windowsWrapperRoot, relativePath) + ".tmpl";
}

async function seedWrappers(
  workspace: TestWorkspace,
  relativePath: string,
  content: string = wrapperTemplate(relativePath),
): Promise<void> {
  await writeFile(unixWrapperPath(workspace, relativePath), content);
  await writeFile(windowsWrapperPath(workspace, relativePath), content);
}

describe("log mode helpers", () => {
  const logModeCases: Array<[string, LogMode]> = [
    ["", "info"],
    ["chezmoi apply -v", "verbose"],
    ["chezmoi apply --verbose", "verbose"],
    ["chezmoi apply -v --debug", "debug"],
  ];

  test("tokenizes quoted shell words from CHEZMOI_ARGS", () => {
    expect(
      tokenizeShellWords(`chezmoi apply --config "/tmp/chez moi.toml" --debug`),
    ).toEqual([
      "chezmoi",
      "apply",
      "--config",
      "/tmp/chez moi.toml",
      "--debug",
    ]);
  });

  test.each(logModeCases)("resolves %p to %p", (rawArgs, expectedMode) => {
    expect(resolveLogMode(rawArgs)).toBe(expectedMode);
  });
});

describe("reconcileNvimConfig", () => {
  test("generates wrappers for visible raw files and ignores dotfile basenames", async () => {
    const workspace = await createWorkspace();

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await writeFile(
      path.join(workspace.rawRoot, "lua", "core", "options.lua"),
      "vim.o.number = true\n",
    );
    await writeFile(path.join(workspace.rawRoot, ".ignored.lua"), "ignored\n");
    await writeFile(path.join(workspace.rawRoot, ".private", "visible.lua"), "return {}\n");

    const summary = await reconcileNvimConfig(
      makeRunOptions(workspace, { logMode: "verbose" }),
    );

    expect(summary).toEqual({
      raw: 3,
      added: 3,
      removed: 0,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
    });

    expect(await readFile(unixWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate("init.lua"),
    );
    expect(await readFile(unixWrapperPath(workspace, "lua/core/options.lua"))).toBe(
      wrapperTemplate("lua/core/options.lua"),
    );
    expect(await readFile(unixWrapperPath(workspace, ".private/visible.lua"))).toBe(
      wrapperTemplate(".private/visible.lua"),
    );
    expect(await readFile(windowsWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate("init.lua"),
    );
    expect(await exists(unixWrapperPath(workspace, ".ignored.lua"))).toBe(false);

    const stdout = workspace.stdout.join("");
    expect(stdout).toContain("VERBOSE: [reconcile-nvim-config] Scanned 3 raw Neovim file(s)");
    expect(stdout).toContain(
      "VERBOSE: [reconcile-nvim-config] Added raw file: home/.shared-configs/nvim/init.lua",
    );
    expect(stdout).toContain(
      "VERBOSE: [reconcile-nvim-config] Added raw file: home/.shared-configs/nvim/lua/core/options.lua",
    );
    expect(stdout).toContain(
      "VERBOSE: [reconcile-nvim-config] Added raw file: home/.shared-configs/nvim/.private/visible.lua",
    );
    expect(stdout).toContain(
      `INFO: [reconcile-nvim-config] raw=3 added=3 removed=0 host=unix target_root=${path.join(workspace.hostHome, ".config", "nvim")}`,
    );
    expect(workspace.stderr).toHaveLength(0);
  });

  test("removes stale wrappers, prunes empty directories, and keeps only relevant host manifest entries", async () => {
    const workspace = await createWorkspace();

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await seedWrappers(workspace, "init.lua");
    await writeFile(
      unixWrapperPath(workspace, "plugin/old.lua"),
      wrapperTemplate("plugin/old.lua"),
    );
    await writeFile(
      workspace.removeManifestPath,
      [
        ".config/nvim/plugin/keep.lua",
        "AppData/Local/nvim/plugin/windows-only.lua",
        ".config/nvim/plugin/gone.lua",
      ].join("\n") + "\n",
    );
    await writeFile(
      path.join(workspace.hostHome, ".config", "nvim", "plugin", "keep.lua"),
      "-- keep stale target\n",
    );

    const summary = await reconcileNvimConfig(makeRunOptions(workspace));

    expect(summary).toEqual({
      raw: 1,
      added: 0,
      removed: 1,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
    });
    expect(await exists(unixWrapperPath(workspace, "plugin/old.lua"))).toBe(false);
    expect(await exists(path.join(workspace.unixWrapperRoot, "plugin"))).toBe(false);
    expect(await readFile(workspace.removeManifestPath)).toBe(
      [".config/nvim/plugin/keep.lua", ".config/nvim/plugin/old.lua"].join("\n") + "\n",
    );
  });

  test("repairs wrapper content without counting the file as added or removed", async () => {
    const workspace = await createWorkspace();

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await seedWrappers(workspace, "init.lua", "wrong wrapper\n");

    const summary = await reconcileNvimConfig(makeRunOptions(workspace));

    expect(summary).toEqual({
      raw: 1,
      added: 0,
      removed: 0,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
    });
    expect(await readFile(unixWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate("init.lua"),
    );
    expect(await readFile(windowsWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate("init.lua"),
    );
    expect(workspace.stdout).toHaveLength(1);
    expect(workspace.stdout[0]).toContain(
      `INFO: [reconcile-nvim-config] raw=1 added=0 removed=0 host=unix target_root=${path.join(workspace.hostHome, ".config", "nvim")}`,
    );
  });

  test("writes windows-host stale targets with the windows prefix and emits debug logs", async () => {
    const workspace = await createWorkspace();

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await seedWrappers(workspace, "init.lua");
    await writeFile(
      windowsWrapperPath(workspace, "plugin/old.lua"),
      wrapperTemplate("plugin/old.lua"),
    );

    const summary = await reconcileNvimConfig(
      makeRunOptions(workspace, { hostKind: "windows", logMode: "debug" }),
    );

    expect(summary).toEqual({
      raw: 1,
      added: 0,
      removed: 1,
      host: "windows",
      targetRoot: path.join(workspace.hostHome, "AppData", "Local", "nvim"),
    });
    expect(await readFile(workspace.removeManifestPath)).toBe(
      "AppData/Local/nvim/plugin/old.lua\n",
    );

    const stdout = workspace.stdout.join("");
    expect(stdout).toContain(
      "DEBUG: [reconcile-nvim-config] Configuration loaded: host=windows log_mode=debug",
    );
    expect(stdout).toContain(
      `DEBUG: [reconcile-nvim-config] Host target root: ${path.join(workspace.hostHome, "AppData", "Local", "nvim")}`,
    );
    expect(stdout).toContain("VERBOSE: [reconcile-nvim-config] Scanned 1 raw Neovim file(s)");
    expect(workspace.stderr).toHaveLength(0);
  });

  test("fails when the canonical raw root is missing", async () => {
    const workspace = await createWorkspace();

    await fs.rm(workspace.rawRoot, { recursive: true, force: true });

    await expect(reconcileNvimConfig(makeRunOptions(workspace))).rejects.toThrow(
      `canonical raw Neovim tree not found: ${workspace.rawRoot}`,
    );
  });
});
