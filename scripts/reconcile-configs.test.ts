import { afterEach, describe, expect, test } from "bun:test";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  reconcileAllTools,
  reconcileTool,
  resolveBasePaths,
  resolveLogMode,
  resolvePathOverrides,
  runCli,
  tokenizeShellWords,
  type LogMode,
  type PlatformKind,
  type ReconcileOptions,
} from "./reconcile-configs.ts";
import { type ToolConfig, validateToolRegistry } from "./tools.config.ts";

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

const nvimTool: ToolConfig = {
  name: "nvim",
  source: ".shared-configs/nvim",
  targets: {
    unix: {
      wrapperRoot: "dot_config/nvim",
      targetPrefix: ".config/nvim",
    },
    windows: {
      wrapperRoot: "AppData/Local/nvim",
      targetPrefix: "AppData/Local/nvim",
    },
  },
};

const tempDirs: string[] = [];

afterEach(async () => {
  await Promise.all(
    tempDirs.map((targetPath) => fs.rm(targetPath, { recursive: true, force: true })),
  );
  tempDirs.length = 0;
});

async function createWorkspace(tool: ToolConfig = nvimTool): Promise<TestWorkspace> {
  const repoRoot = await fs.mkdtemp(path.join(os.tmpdir(), "reconcile-configs-test-"));
  tempDirs.push(repoRoot);

  const sourceStateRoot = path.join(repoRoot, "home");
  const rawRoot = path.join(sourceStateRoot, ...tool.source.split("/"));
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
    unixWrapperRoot: path.join(sourceStateRoot, ...tool.targets.unix.wrapperRoot.split("/")),
    windowsWrapperRoot: path.join(sourceStateRoot, ...tool.targets.windows.wrapperRoot.split("/")),
  };
}

function makeRunOptions(
  workspace: TestWorkspace,
  overrides: Partial<{
    hostKind: PlatformKind;
    logMode: LogMode;
  }> = {},
): ReconcileOptions {
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

async function sleep(milliseconds: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function wrapperTemplate(toolSource: string, relativePath: string): string {
  return `{{- include "${path.posix.join(toolSource, relativePath)}" -}}`;
}

function unixWrapperPath(workspace: TestWorkspace, relativePath: string): string {
  return path.join(workspace.unixWrapperRoot, relativePath) + ".tmpl";
}

function windowsWrapperPath(workspace: TestWorkspace, relativePath: string): string {
  return path.join(workspace.windowsWrapperRoot, relativePath) + ".tmpl";
}

async function seedWrappers(
  workspace: TestWorkspace,
  tool: ToolConfig,
  relativePath: string,
  content?: string,
): Promise<void> {
  const wrapperContent =
    content ?? wrapperTemplate(tool.source, relativePath);
  await writeFile(unixWrapperPath(workspace, relativePath), wrapperContent);
  await writeFile(windowsWrapperPath(workspace, relativePath), wrapperContent);
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

  test("tokenizes single-quoted values and ignores repeated spaces", () => {
    expect(
      tokenizeShellWords(`  chezmoi   apply   --config   '/tmp/chez moi.toml'   -v  `),
    ).toEqual([
      "chezmoi",
      "apply",
      "--config",
      "/tmp/chez moi.toml",
      "-v",
    ]);
  });

  test("keeps quoted flag values intact when the quote starts after =", () => {
    expect(
      tokenizeShellWords(`chezmoi apply --source="/tmp/my -v repo" --debug`),
    ).toEqual([
      "chezmoi",
      "apply",
      "--source=/tmp/my -v repo",
      "--debug",
    ]);
  });

  test.each(logModeCases)("resolves %p to %p", (rawArgs, expectedMode) => {
    expect(resolveLogMode(rawArgs)).toBe(expectedMode);
  });

  test("does not treat -v inside a quoted flag value as verbose mode", () => {
    expect(resolveLogMode(`chezmoi apply --source="/tmp/my -v repo"`)).toBe("info");
  });

  test("does not treat --debug inside a quoted flag value as debug mode", () => {
    expect(resolveLogMode(`chezmoi apply --source="/tmp/my --debug repo"`)).toBe(
      "info",
    );
  });
});

describe("resolvePathOverrides", () => {
  test("returns empty overrides when no path flags are present", () => {
    expect(resolvePathOverrides("chezmoi apply -v")).toEqual({
      sourceDir: undefined,
      workingTree: undefined,
    });
  });

  test("resolves --source to sourceDir", () => {
    expect(resolvePathOverrides("chezmoi apply --source /tmp/worktree/home")).toEqual({
      sourceDir: "/tmp/worktree/home",
      workingTree: undefined,
    });
  });

  test("resolves -S short flag to sourceDir", () => {
    expect(resolvePathOverrides("chezmoi apply -S /tmp/worktree/home")).toEqual({
      sourceDir: "/tmp/worktree/home",
      workingTree: undefined,
    });
  });

  test("resolves --working-tree to workingTree", () => {
    expect(resolvePathOverrides("chezmoi apply --working-tree /tmp/worktree")).toEqual({
      sourceDir: undefined,
      workingTree: "/tmp/worktree",
    });
  });

  test("resolves -W short flag to workingTree", () => {
    expect(resolvePathOverrides("chezmoi apply -W /tmp/worktree")).toEqual({
      sourceDir: undefined,
      workingTree: "/tmp/worktree",
    });
  });

  test("resolves both flags together", () => {
    expect(
      resolvePathOverrides(
        "chezmoi apply -S /tmp/worktree/home -W /tmp/worktree",
      ),
    ).toEqual({
      sourceDir: "/tmp/worktree/home",
      workingTree: "/tmp/worktree",
    });
  });

  test("resolves long flags together with extra flags", () => {
    expect(
      resolvePathOverrides(
        "chezmoi diff --init --source /wt/home --working-tree /wt -v",
      ),
    ).toEqual({
      sourceDir: "/wt/home",
      workingTree: "/wt",
    });
  });

  test("handles quoted paths with spaces", () => {
    expect(
      resolvePathOverrides(
        `chezmoi apply -S "/tmp/my worktree/home" -W "/tmp/my worktree"`,
      ),
    ).toEqual({
      sourceDir: "/tmp/my worktree/home",
      workingTree: "/tmp/my worktree",
    });
  });

  test("preserves backslashes in quoted Windows paths", () => {
    expect(
      resolvePathOverrides(
        String.raw`chezmoi apply -S "C:\Users\me\repo\home" -W "C:\Users\me\repo"`,
      ),
    ).toEqual({
      sourceDir: String.raw`C:\Users\me\repo\home`,
      workingTree: String.raw`C:\Users\me\repo`,
    });
  });

  test("returns empty overrides for empty args", () => {
    expect(resolvePathOverrides("")).toEqual({
      sourceDir: undefined,
      workingTree: undefined,
    });
  });
});

describe("resolveBasePaths", () => {
  test("falls back to .chezmoiroot when no overrides are present", async () => {
    const repoRoot = await fs.mkdtemp(path.join(os.tmpdir(), "chezmoi-paths-test-"));
    tempDirs.push(repoRoot);
    await fs.writeFile(path.join(repoRoot, ".chezmoiroot"), "dotfiles\n", "utf8");

    expect(resolveBasePaths({}, repoRoot, "")).toEqual({
      repoRoot,
      sourceStateRoot: path.join(repoRoot, "dotfiles"),
    });
  });
});

describe("reconcileTool (nvim)", () => {
  test("generates wrappers for visible raw files and ignores dotfile basenames", async () => {
    const workspace = await createWorkspace(nvimTool);

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await writeFile(
      path.join(workspace.rawRoot, "lua", "core", "options.lua"),
      "vim.o.number = true\n",
    );
    await writeFile(path.join(workspace.rawRoot, ".ignored.lua"), "ignored\n");
    await writeFile(path.join(workspace.rawRoot, ".private", "visible.lua"), "return {}\n");

    const summary = await reconcileTool(
      nvimTool,
      makeRunOptions(workspace, { logMode: "verbose" }),
    );

    expect(summary).toEqual({
      raw: 3,
      added: 3,
      removed: 0,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
      toolName: "nvim",
    });

    expect(await readFile(unixWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate(nvimTool.source, "init.lua"),
    );
    expect(await readFile(unixWrapperPath(workspace, "lua/core/options.lua"))).toBe(
      wrapperTemplate(nvimTool.source, "lua/core/options.lua"),
    );
    expect(await readFile(unixWrapperPath(workspace, ".private/visible.lua"))).toBe(
      wrapperTemplate(nvimTool.source, ".private/visible.lua"),
    );
    expect(await readFile(windowsWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate(nvimTool.source, "init.lua"),
    );
    expect(await exists(unixWrapperPath(workspace, ".ignored.lua"))).toBe(false);

    const stdout = workspace.stdout.join("");
    expect(stdout).toContain("VERBOSE: [reconcile-configs/nvim] Scanned 3 raw nvim file(s)");
    expect(stdout).toContain(
      "VERBOSE: [reconcile-configs/nvim] Added raw file: home/.shared-configs/nvim/init.lua",
    );
    expect(stdout).toContain(
      "VERBOSE: [reconcile-configs/nvim] Added raw file: home/.shared-configs/nvim/lua/core/options.lua",
    );
    expect(stdout).toContain(
      "VERBOSE: [reconcile-configs/nvim] Added raw file: home/.shared-configs/nvim/.private/visible.lua",
    );
    expect(stdout).toContain(
      `INFO: [reconcile-configs/nvim] tool=nvim raw=3 added=3 removed=0 host=unix target_root=${path.join(workspace.hostHome, ".config", "nvim")}`,
    );
    expect(workspace.stderr).toHaveLength(0);
  });

  test("removes stale wrappers, prunes empty directories, and keeps only relevant host manifest entries", async () => {
    const workspace = await createWorkspace(nvimTool);

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await seedWrappers(workspace, nvimTool, "init.lua");
    await seedWrappers(workspace, nvimTool, "plugin/old.lua");
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

    const summary = await reconcileTool(nvimTool, makeRunOptions(workspace));

    expect(summary).toEqual({
      raw: 1,
      added: 0,
      removed: 1,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
      toolName: "nvim",
    });
    expect(await exists(unixWrapperPath(workspace, "plugin/old.lua"))).toBe(false);
    expect(await exists(windowsWrapperPath(workspace, "plugin/old.lua"))).toBe(false);
    expect(await exists(path.join(workspace.unixWrapperRoot, "plugin"))).toBe(false);
    expect(await exists(path.join(workspace.windowsWrapperRoot, "plugin"))).toBe(false);
    expect(await readFile(workspace.removeManifestPath)).toBe(
      [".config/nvim/plugin/keep.lua", ".config/nvim/plugin/old.lua"].join("\n") + "\n",
    );
  });

  test("repairs wrapper content without counting the file as added or removed", async () => {
    const workspace = await createWorkspace(nvimTool);

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await seedWrappers(workspace, nvimTool, "init.lua", "wrong wrapper\n");

    const summary = await reconcileTool(nvimTool, makeRunOptions(workspace));

    expect(summary).toEqual({
      raw: 1,
      added: 0,
      removed: 0,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
      toolName: "nvim",
    });
    expect(await readFile(unixWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate(nvimTool.source, "init.lua"),
    );
    expect(await readFile(windowsWrapperPath(workspace, "init.lua"))).toBe(
      wrapperTemplate(nvimTool.source, "init.lua"),
    );
    expect(workspace.stdout).toHaveLength(1);
    expect(workspace.stdout[0]).toContain(
      `INFO: [reconcile-configs/nvim] tool=nvim raw=1 added=0 removed=0 host=unix target_root=${path.join(workspace.hostHome, ".config", "nvim")}`,
    );
  });

  test("is idempotent on the second run and does not rewrite unchanged files", async () => {
    const workspace = await createWorkspace(nvimTool);

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");

    const firstSummary = await reconcileTool(nvimTool, makeRunOptions(workspace));
    const wrapperPath = unixWrapperPath(workspace, "init.lua");
    const manifestPath = workspace.removeManifestPath;
    const wrapperStatBefore = await fs.stat(wrapperPath);
    const manifestStatBefore = await fs.stat(manifestPath);

    await sleep(25);

    const secondSummary = await reconcileTool(nvimTool, makeRunOptions(workspace));
    const wrapperStatAfter = await fs.stat(wrapperPath);
    const manifestStatAfter = await fs.stat(manifestPath);

    expect(firstSummary).toEqual({
      raw: 1,
      added: 1,
      removed: 0,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
      toolName: "nvim",
    });
    expect(secondSummary).toEqual({
      raw: 1,
      added: 0,
      removed: 0,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
      toolName: "nvim",
    });
    expect(wrapperStatAfter.mtimeMs).toBe(wrapperStatBefore.mtimeMs);
    expect(manifestStatAfter.mtimeMs).toBe(manifestStatBefore.mtimeMs);
  });

  test("accepts an empty raw tree without errors", async () => {
    const workspace = await createWorkspace(nvimTool);

    const summary = await reconcileTool(nvimTool, makeRunOptions(workspace));

    expect(summary).toEqual({
      raw: 0,
      added: 0,
      removed: 0,
      host: "unix",
      targetRoot: path.join(workspace.hostHome, ".config", "nvim"),
      toolName: "nvim",
    });
    expect(workspace.stderr).toHaveLength(0);

    if (await exists(workspace.removeManifestPath)) {
      expect(await readFile(workspace.removeManifestPath)).toBe("");
    }
  });

  test("writes windows-host stale targets with the windows prefix and emits debug logs", async () => {
    const workspace = await createWorkspace(nvimTool);

    await writeFile(path.join(workspace.rawRoot, "init.lua"), "print('init')\n");
    await seedWrappers(workspace, nvimTool, "init.lua");
    await seedWrappers(workspace, nvimTool, "plugin/old.lua");

    const summary = await reconcileTool(
      nvimTool,
      makeRunOptions(workspace, { hostKind: "windows", logMode: "debug" }),
    );

    expect(summary).toEqual({
      raw: 1,
      added: 0,
      removed: 1,
      host: "windows",
      targetRoot: path.join(workspace.hostHome, "AppData", "Local", "nvim"),
      toolName: "nvim",
    });
    expect(await readFile(workspace.removeManifestPath)).toBe(
      "AppData/Local/nvim/plugin/old.lua\n",
    );
    expect(await exists(unixWrapperPath(workspace, "plugin/old.lua"))).toBe(false);
    expect(await exists(windowsWrapperPath(workspace, "plugin/old.lua"))).toBe(false);

    const stdout = workspace.stdout.join("");
    expect(stdout).toContain(
      "DEBUG: [reconcile-configs/nvim] Configuration loaded: host=windows log_mode=debug",
    );
    expect(stdout).toContain(
      `DEBUG: [reconcile-configs/nvim] Host target root: ${path.join(workspace.hostHome, "AppData", "Local", "nvim")}`,
    );
    expect(stdout).toContain("VERBOSE: [reconcile-configs/nvim] Scanned 1 raw nvim file(s)");
    expect(workspace.stderr).toHaveLength(0);
  });

  test("fails when the canonical raw root is missing", async () => {
    const workspace = await createWorkspace(nvimTool);

    await fs.rm(workspace.rawRoot, { recursive: true, force: true });

    expect(reconcileTool(nvimTool, makeRunOptions(workspace))).rejects.toThrow(
      `canonical raw tree not found for tool "nvim": ${workspace.rawRoot}`,
    );
  });

  test("runCli writes fallback stderr output and exits non-zero on startup errors", async () => {
    const workspace = await createWorkspace(nvimTool);
    const stderr: string[] = [];
    const exitCodes: number[] = [];

    await runCli({
      hostKind: "invalid" as PlatformKind,
      now: () => new Date(2026, 3, 5, 12, 34, 56),
      repoRoot: workspace.repoRoot,
      stderr: (line: string) => stderr.push(line),
      exit: (code: number) => {
        exitCodes.push(code);
      },
    });

    expect(exitCodes).toEqual([1]);
    expect(stderr).toHaveLength(1);
    expect(stderr[0]).toContain("[2026-04-05 12:34:56] ERROR: [reconcile-configs]");
    expect(stderr[0]).toContain("unsupported host platform: invalid");
  });
});

describe("reconcileAllTools", () => {
  const extraTool: ToolConfig = {
    name: "extra",
    source: ".shared-configs/extra",
    targets: {
      unix: {
        wrapperRoot: "dot_config/extra",
        targetPrefix: ".config/extra",
      },
      windows: {
        wrapperRoot: "AppData/Local/extra",
        targetPrefix: "AppData/Local/extra",
      },
    },
  };

  test("reconciles multiple tools in sequence", async () => {
    const repoRoot = await fs.mkdtemp(path.join(os.tmpdir(), "reconcile-multi-test-"));
    tempDirs.push(repoRoot);

    const sourceStateRoot = path.join(repoRoot, "home");
    const nvimRaw = path.join(sourceStateRoot, ".shared-configs", "nvim");
    const extraRaw = path.join(sourceStateRoot, ".shared-configs", "extra");
    const hostHome = path.join(repoRoot, "host-home");

    await fs.mkdir(nvimRaw, { recursive: true });
    await fs.mkdir(extraRaw, { recursive: true });
    await fs.mkdir(hostHome, { recursive: true });

    await writeFile(path.join(nvimRaw, "init.lua"), "print('nvim')\n");
    await writeFile(path.join(extraRaw, "config.toml"), "key = 'value'\n");

    const stdout: string[] = [];
    const result = await reconcileAllTools(
      {
        hostHome,
        hostKind: "unix",
        logMode: "info",
        repoRoot,
        stdout: (line) => stdout.push(line),
        stderr: () => {},
      },
      [nvimTool, extraTool],
    );

    expect(result.tools).toHaveLength(2);
    expect(result.tools[0]).toEqual({
      raw: 1,
      added: 1,
      removed: 0,
      host: "unix",
      targetRoot: path.join(hostHome, ".config", "nvim"),
      toolName: "nvim",
    });
    expect(result.tools[1]).toEqual({
      raw: 1,
      added: 1,
      removed: 0,
      host: "unix",
      targetRoot: path.join(hostHome, ".config", "extra"),
      toolName: "extra",
    });

    // Verify wrappers exist for both tools
    expect(
      await readFile(
        path.join(sourceStateRoot, "dot_config", "nvim", "init.lua.tmpl"),
      ),
    ).toBe(wrapperTemplate(nvimTool.source, "init.lua"));
    expect(
      await readFile(
        path.join(sourceStateRoot, "dot_config", "extra", "config.toml.tmpl"),
      ),
    ).toBe(wrapperTemplate(extraTool.source, "config.toml"));
  });

  test("handles empty tool list safely", async () => {
    const repoRoot = await fs.mkdtemp(path.join(os.tmpdir(), "reconcile-empty-test-"));
    tempDirs.push(repoRoot);

    const result = await reconcileAllTools(
      {
        repoRoot,
        stderr: () => {},
        stdout: () => {},
      },
      [],
    );

    expect(result.tools).toHaveLength(0);
  });

  test("one tool does not remove another tool's .chezmoiremove entries", async () => {
    const repoRoot = await fs.mkdtemp(path.join(os.tmpdir(), "reconcile-cross-test-"));
    tempDirs.push(repoRoot);

    const sourceStateRoot = path.join(repoRoot, "home");
    const nvimRaw = path.join(sourceStateRoot, ".shared-configs", "nvim");
    const extraRaw = path.join(sourceStateRoot, ".shared-configs", "extra");
    const hostHome = path.join(repoRoot, "host-home");

    await fs.mkdir(nvimRaw, { recursive: true });
    await fs.mkdir(extraRaw, { recursive: true });
    await fs.mkdir(hostHome, { recursive: true });

    // Only nvim has a raw file; extra has none
    await writeFile(path.join(nvimRaw, "init.lua"), "print('init')\n");

    // Pre-existing manifest with entries from both tools
    const manifestPath = path.join(sourceStateRoot, ".chezmoiremove");
    await writeFile(
      manifestPath,
      ".config/nvim/stale.lua\n.config/extra/old.toml\n",
    );

    // Create stale targets on disk so they're kept
    await writeFile(
      path.join(hostHome, ".config", "nvim", "stale.lua"),
      "-- stale\n",
    );
    await writeFile(
      path.join(hostHome, ".config", "extra", "old.toml"),
      "# old\n",
    );

    await reconcileAllTools(
      {
        hostHome,
        hostKind: "unix",
        logMode: "info",
        repoRoot,
        stderr: () => {},
        stdout: () => {},
      },
      [nvimTool, extraTool],
    );

    // Both stale entries should be preserved — extra tool should not erase nvim's entries
    const manifest = await readFile(manifestPath);
    expect(manifest).toContain(".config/nvim/stale.lua");
    expect(manifest).toContain(".config/extra/old.toml");
  });

  test("tool with empty raw tree produces zero wrappers", async () => {
    const repoRoot = await fs.mkdtemp(path.join(os.tmpdir(), "reconcile-empty-raw-test-"));
    tempDirs.push(repoRoot);

    const sourceStateRoot = path.join(repoRoot, "home");
    const nvimRaw = path.join(sourceStateRoot, ".shared-configs", "nvim");
    const hostHome = path.join(repoRoot, "host-home");

    await fs.mkdir(nvimRaw, { recursive: true });
    await fs.mkdir(hostHome, { recursive: true });

    const result = await reconcileAllTools(
      {
        hostHome,
        hostKind: "unix",
        logMode: "info",
        repoRoot,
        stderr: () => {},
        stdout: () => {},
      },
      [nvimTool],
    );

    expect(result.tools).toHaveLength(1);
    expect(result.tools[0]).toEqual({
      raw: 0,
      added: 0,
      removed: 0,
      host: "unix",
      targetRoot: path.join(hostHome, ".config", "nvim"),
      toolName: "nvim",
    });
  });
});

describe("validateToolRegistry", () => {
  test("accepts a valid tool list", () => {
    expect(() => validateToolRegistry([nvimTool])).not.toThrow();
  });

  test("rejects duplicate tool names", () => {
    const dup: ToolConfig = { ...nvimTool, source: ".shared-configs/other" };
    expect(() => validateToolRegistry([nvimTool, dup])).toThrow("duplicate tool name: nvim");
  });

  test("rejects duplicate tool sources", () => {
    const dup: ToolConfig = { ...nvimTool, name: "other" };
    expect(() => validateToolRegistry([nvimTool, dup])).toThrow(
      "duplicate tool source: .shared-configs/nvim",
    );
  });

  test("rejects duplicate wrapper roots per platform", () => {
    const dup: ToolConfig = {
      name: "other",
      source: ".shared-configs/other",
      targets: {
        unix: { wrapperRoot: "dot_config/nvim", targetPrefix: ".config/other" },
        windows: { wrapperRoot: "AppData/Local/other", targetPrefix: "AppData/Local/other" },
      },
    };
    expect(() => validateToolRegistry([nvimTool, dup])).toThrow(
      "duplicate wrapper root for unix: dot_config/nvim",
    );
  });

  test("rejects duplicate target prefixes per platform", () => {
    const dup: ToolConfig = {
      name: "other",
      source: ".shared-configs/other",
      targets: {
        unix: { wrapperRoot: "dot_config/other", targetPrefix: ".config/nvim" },
        windows: { wrapperRoot: "AppData/Local/other", targetPrefix: "AppData/Local/other" },
      },
    };
    expect(() => validateToolRegistry([nvimTool, dup])).toThrow(
      "duplicate target prefix for unix: .config/nvim",
    );
  });
});
