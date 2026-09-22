import { describe, expect, spyOn, test } from "bun:test";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  createActiveSession,
  enumerateCandidates,
  inspectCandidates,
  isPathInside,
  markSessionReady,
  openActiveSession,
  parseNulPaths,
  removeActiveSession,
  resolveNormalSourceCheckout,
  resolveSessionBase,
  snapshotRuntime,
  stageWorktreeSource,
  stagedRuntime,
  validateSafeRemovalPath,
  validateStagedSource,
  type CandidateTarget,
} from "./worktree-session.ts";
import {
  type ChezmoiRuntime,
  type CommandResult,
  type CommandRunner,
} from "./worktree-runtime.ts";

describe("managed output parsing", () => {
  test("parses NUL paths without splitting spaces", () => {
    expect(parseNulPaths(Buffer.from("/home/u/a b\0/home/u/c\0"))).toEqual([
      "/home/u/a b",
      "/home/u/c",
    ]);
  });

  test("accepts empty managed output", () => {
    expect(parseNulPaths(Buffer.alloc(0))).toEqual([]);
  });

  test("rejects non-terminated managed output", () => {
    expect(() => parseNulPaths(Buffer.from("/home/u/a"))).toThrow(
      "managed output is not NUL-terminated",
    );
  });

  test.each([Buffer.from("\0"), Buffer.from("/abs/a\0\0")])(
    "rejects an empty NUL record",
    (output) => {
      expect(() => parseNulPaths(output)).toThrow("managed output contains an empty path");
    },
  );

  test("rejects invalid UTF-8", () => {
    expect(() => parseNulPaths(Buffer.from([0xff, 0x00]))).toThrow(
      "managed output is not valid UTF-8",
    );
  });
});

test.each(["", "a*", "a?", "[a]", "{a}", "!keep", "a#comment", "a\\b", " a", "a ", "a\r", "a\n"])(
  "rejects unsafe removal path %s",
  (value) => expect(() => validateSafeRemovalPath(value)).toThrow("unsafe removal path"),
);

test("accepts a literal relative removal path", () => {
  expect(() => validateSafeRemovalPath(".config/a b")).not.toThrow();
});

test("resolves per-platform state roots", () => {
  expect(resolveSessionBase("linux", "/home/u", { XDG_STATE_HOME: "/state" })).toBe(
    "/state/chezmoi-worktree-test",
  );
  expect(resolveSessionBase("darwin", "/Users/u", {})).toBe(
    "/Users/u/Library/Application Support/chezmoi-worktree-test",
  );
  expect(resolveSessionBase("win32", "C:\\Users\\u", { LOCALAPPDATA: "C:\\Local" })).toBe(
    "C:\\Local\\chezmoi-worktree-test",
  );
  expect(resolveSessionBase("linux", "/home/u", {})).toBe(
    "/home/u/.local/state/chezmoi-worktree-test",
  );
  expect(resolveSessionBase("win32", "C:\\Users\\u", {})).toBe(
    "C:\\Users\\u\\AppData\\Local\\chezmoi-worktree-test",
  );
});

test("writes ready only after explicit mark", async () => {
  const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
  const session = await createActiveSession(base, "/repo", "/home/u");

  await expect(fs.stat(session.readyFile)).rejects.toMatchObject({ code: "ENOENT" });
  await markSessionReady(session);

  expect(await fs.readFile(session.readyFile, "utf8")).toBe("ready\n");
  expect((await fs.stat(session.readyFile)).mode & 0o777).toBe(0o600);
});

describe("active session lifecycle", () => {
  test("cleans failed setup so a later apply can create a session", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    try {
      const write = spyOn(fs, "writeFile").mockRejectedValueOnce(new Error("setup failed"));
      try {
        await expect(createActiveSession(base, "/repo", "/home/u")).rejects.toThrow("setup failed");
      } finally {
        write.mockRestore();
      }

      await expect(fs.stat(path.join(base, "active"))).rejects.toMatchObject({ code: "ENOENT" });
      const session = await createActiveSession(base, "/repo", "/home/u");
      expect(await fs.readFile(session.configFile, "utf8")).toBe("");
      await removeActiveSession(session);
    } finally {
      await fs.rm(base, { recursive: true, force: true });
    }
  });

  test("creates the exact isolated paths with restrictive modes", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");

    expect(session).toEqual({
      activeDir: path.join(base, "active"),
      cacheDir: path.join(base, "active", "cache"),
      configFile: path.join(base, "active", "config.toml"),
      destinationDir: "/home/u",
      persistentStateFile: path.join(base, "active", "state.boltdb"),
      readyFile: path.join(base, "active", "ready"),
      snapshotSourceDir: path.join(base, "active", "snapshot-source"),
      stagedSourceDir: path.join(base, "active", "staged-source"),
      worktreeRoot: "/repo",
    });
    expect((await fs.stat(session.activeDir)).mode & 0o777).toBe(0o700);
    expect((await fs.stat(session.cacheDir)).mode & 0o777).toBe(0o700);
    expect((await fs.stat(session.snapshotSourceDir)).mode & 0o777).toBe(0o700);
    expect((await fs.stat(session.configFile)).mode & 0o777).toBe(0o600);
    expect(await fs.readFile(session.configFile, "utf8")).toBe("");
    await expect(fs.stat(session.stagedSourceDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("rejects a second active session with the stable lock error", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    await createActiveSession(base, "/repo", "/home/u");

    await expect(createActiveSession(base, "/repo", "/home/u")).rejects.toThrow(
      "an active worktree test session already exists",
    );
  });

  test("opens an existing session and rejects a missing session", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const created = await createActiveSession(base, "/repo", "/home/u");

    expect(await openActiveSession(base, "/repo", "/home/u")).toEqual(created);
    await removeActiveSession(created);
    await expect(openActiveSession(base, "/repo", "/home/u")).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  test("removes only the exact active directory", async () => {
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const sibling = path.join(base, "keep");
    await fs.writeFile(sibling, "keep\n");
    const session = await createActiveSession(base, "/repo", "/home/u");

    await removeActiveSession(session);

    await expect(fs.stat(session.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
    expect(await fs.readFile(sibling, "utf8")).toBe("keep\n");
  });
});

test("projects staged and snapshot runtimes without changing destination state", async () => {
  const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
  const session = await createActiveSession(base, "/repo", "/home/u");

  expect(stagedRuntime(session)).toEqual({
    cacheDir: session.cacheDir,
    configFile: session.configFile,
    destinationDir: "/home/u",
    persistentStateFile: session.persistentStateFile,
    sourceDir: session.stagedSourceDir,
    worktreeRoot: "/repo",
  });
  expect(snapshotRuntime(session)).toEqual({
    cacheDir: session.cacheDir,
    configFile: session.configFile,
    destinationDir: "/home/u",
    persistentStateFile: session.persistentStateFile,
    sourceDir: session.snapshotSourceDir,
    worktreeRoot: session.activeDir,
  });
});

function commandResult(overrides: Partial<CommandResult> = {}): CommandResult {
  return {
    signal: null,
    status: 0,
    stderr: Buffer.alloc(0),
    stdout: Buffer.alloc(0),
    ...overrides,
  };
}

describe("managed candidate inventory", () => {
  test("classifies each managed kind using exact NUL-output calls", async () => {
    const outputs: Record<string, string> = {
      dirs: "/home/u/.config\0",
      files: "/home/u/.config/nvim/init.lua\0",
      remove: "/home/u/old\0",
      symlinks: "/home/u/.link\0",
    };
    const invocations: Array<{ args: string[]; command: string }> = [];
    const runner: CommandRunner = (command, args) => {
      invocations.push({ args, command });
      const includeIndex = args.indexOf("--include");
      const include = args[includeIndex + 1] ?? "";
      return commandResult({ stdout: Buffer.from(outputs[include] ?? "") });
    };

    const candidates = await enumerateCandidates(candidateRuntime(), runner);

    expect([...candidates.values()]).toEqual([
      { absolutePath: "/home/u/.config", managedKind: "directory" },
      { absolutePath: "/home/u/.config/nvim/init.lua", managedKind: "file" },
      { absolutePath: "/home/u/.link", managedKind: "symlink" },
      { absolutePath: "/home/u/old", managedKind: "remove" },
    ]);
    expect(
      invocations.map(({ args, command }) => ({ command, args: args.slice(-6) })),
    ).toEqual([
      {
        command: "chezmoi",
        args: [
          "managed",
          "--include",
          "dirs",
          "--path-style",
          "absolute",
          "--nul-path-separator",
        ],
      },
      {
        command: "chezmoi",
        args: [
          "managed",
          "--include",
          "files",
          "--path-style",
          "absolute",
          "--nul-path-separator",
        ],
      },
      {
        command: "chezmoi",
        args: [
          "managed",
          "--include",
          "symlinks",
          "--path-style",
          "absolute",
          "--nul-path-separator",
        ],
      },
      {
        command: "chezmoi",
        args: [
          "managed",
          "--include",
          "remove",
          "--path-style",
          "absolute",
          "--nul-path-separator",
        ],
      },
    ]);
  });

  test("rejects a target reported under conflicting managed kinds", async () => {
    const runner: CommandRunner = (_command, args) => {
      const includeIndex = args.indexOf("--include");
      const include = args[includeIndex + 1];
      return commandResult({
        stdout: Buffer.from(include === "dirs" || include === "files" ? "/home/u/.same\0" : ""),
      });
    };

    await expect(enumerateCandidates(candidateRuntime(), runner)).rejects.toThrow(
      "conflicting managed target types: /home/u/.same",
    );
  });

  test("requires each managed inventory command to succeed", async () => {
    const runner: CommandRunner = (_command, args) => {
      const includeIndex = args.indexOf("--include");
      if (args[includeIndex + 1] === "files") {
        return commandResult({ status: 1, stderr: Buffer.from("managed failed\n") });
      }
      return commandResult();
    };

    await expect(enumerateCandidates(candidateRuntime(), runner)).rejects.toThrow(
      "managed failed",
    );
  });

  test("rejects a non-absolute managed path before normalization", async () => {
    const runner: CommandRunner = (_command, args) => {
      const includeIndex = args.indexOf("--include");
      return commandResult({
        stdout: Buffer.from(args[includeIndex + 1] === "dirs" ? "relative/path\0" : ""),
      });
    };

    await expect(enumerateCandidates(candidateRuntime(), runner)).rejects.toThrow(
      "managed output path is not absolute: relative/path",
    );
  });
});

function candidateRuntime(): ChezmoiRuntime {
  return {
    cacheDir: "/runtime/cache",
    configFile: "/runtime/config.toml",
    destinationDir: "/home/u",
    persistentStateFile: "/runtime/state.boltdb",
    sourceDir: "/runtime/source",
    worktreeRoot: "/repo",
  };
}

describe("candidate destination preflight", () => {
  test("checks containment without accepting sibling prefixes", () => {
    expect(isPathInside("/home/u", "/home/u/.config/file")).toBeTrue();
    expect(isPathInside("/home/u", "/home/u")).toBeTrue();
    expect(isPathInside("/home/u", "/home/user/.config/file")).toBeFalse();
    expect(isPathInside("/home/u", "/tmp/file")).toBeFalse();
  });

  test("classifies regular, symlink, directory, and absent baselines", async () => {
    const fixture = await makePreflightFixture();
    const regular = path.join(fixture.home, ".regular");
    const symlink = path.join(fixture.home, ".link");
    const directory = path.join(fixture.home, ".config");
    const absentFile = path.join(fixture.home, ".created");
    const absentDirectory = path.join(fixture.home, ".newdir");
    await fs.writeFile(regular, "before\n", { mode: 0o600 });
    await fs.symlink("before-target", symlink);
    await fs.mkdir(directory);
    const candidates = candidateMap([
      [regular, "file"],
      [symlink, "symlink"],
      [directory, "directory"],
      [absentFile, "file"],
      [absentDirectory, "directory"],
    ]);

    await inspectCandidates(candidates, fixture.options);

    expect([...candidates.values()]).toEqual([
      {
        absolutePath: regular,
        baselineKind: "file",
        managedKind: "file",
        relativePath: ".regular",
      },
      {
        absolutePath: symlink,
        baselineKind: "symlink",
        managedKind: "symlink",
        relativePath: ".link",
      },
      {
        absolutePath: directory,
        baselineKind: "directory",
        managedKind: "directory",
        relativePath: ".config",
      },
      {
        absolutePath: absentFile,
        baselineKind: "absent",
        managedKind: "file",
        relativePath: ".created",
      },
      {
        absolutePath: absentDirectory,
        baselineKind: "absent",
        managedKind: "directory",
        relativePath: ".newdir",
      },
    ]);
  });

  test("writes nested relative paths with forward slashes", async () => {
    const fixture = await makePreflightFixture();
    const target = path.join(fixture.home, ".config", "tool", "settings.json");
    const candidates = candidateMap([[target, "file"]]);

    await inspectCandidates(candidates, fixture.options);

    expect(candidates.get(target)?.relativePath).toBe(".config/tool/settings.json");
    expect(candidates.get(target)?.baselineKind).toBe("absent");
  });

  test("rejects a target outside the destination", async () => {
    const fixture = await makePreflightFixture();
    const target = path.join(fixture.root, "outside");

    await expect(
      inspectCandidates(candidateMap([[target, "file"]]), fixture.options),
    ).rejects.toThrow(`managed target is outside destination: ${target}`);
  });

  test("rejects the destination itself as a target", async () => {
    const fixture = await makePreflightFixture();

    await expect(
      inspectCandidates(candidateMap([[fixture.home, "directory"]]), fixture.options),
    ).rejects.toThrow("managed target is outside destination");
  });

  test("rejects hard links that a source snapshot cannot restore", async () => {
    const fixture = await makePreflightFixture();
    const target = path.join(fixture.home, ".hardlink");
    const original = path.join(fixture.home, ".original");
    await fs.writeFile(original, "keep\n");
    await fs.link(original, target);

    await expect(
      inspectCandidates(candidateMap([[target, "file"]]), fixture.options),
    ).rejects.toThrow("unsupported hard-linked target");
  });

  test.each(["carriage\rreturn", "line\nfeed"])(
    "rejects a managed path containing CR/LF: %s",
    async (component) => {
      const fixture = await makePreflightFixture();
      const target = path.join(fixture.home, component);

      await expect(
        inspectCandidates(candidateMap([[target, "file"]]), fixture.options),
      ).rejects.toThrow("managed target contains CR or LF");
    },
  );

  test.each([
    ["session directory", "session"],
    ["worktree root", "worktree"],
    ["normal source directory", "normal"],
  ] as const)("rejects a target inside the %s", async (label, protectedRoot) => {
    const fixture = await makePreflightFixture();
    const target = path.join(fixture[protectedRoot], "managed-file");

    await expect(
      inspectCandidates(candidateMap([[target, "file"]]), fixture.options),
    ).rejects.toThrow(`managed target is inside ${label}: ${target}`);
  });

  test("rejects a symlinked destination ancestor without following it", async () => {
    const fixture = await makePreflightFixture();
    const realDirectory = path.join(fixture.home, "real-config");
    const linkedDirectory = path.join(fixture.home, ".config");
    await fs.mkdir(realDirectory);
    await fs.symlink("real-config", linkedDirectory, "dir");
    const target = path.join(linkedDirectory, "settings.json");

    await expect(
      inspectCandidates(candidateMap([[target, "file"]]), fixture.options),
    ).rejects.toThrow(`managed target has symlinked ancestor: ${linkedDirectory}`);
  });

  test.each(["file", "symlink", "remove"] as const)(
    "rejects an existing directory for a %s target",
    async (managedKind) => {
      const fixture = await makePreflightFixture();
      const target = path.join(fixture.home, ".existing-dir");
      await fs.mkdir(target);

      await expect(
        inspectCandidates(candidateMap([[target, managedKind]]), fixture.options),
      ).rejects.toThrow(`managed non-directory target is an existing directory: ${target}`);
    },
  );

  test("rejects a special destination node", async () => {
    if (process.platform === "win32") return;
    const fixture = await makePreflightFixture();
    const target = path.join(fixture.home, ".pipe");
    const processResult = Bun.spawn(["mkfifo", target], { stderr: "pipe" });
    expect(await processResult.exited).toBe(0);

    await expect(
      inspectCandidates(candidateMap([[target, "file"]]), fixture.options),
    ).rejects.toThrow(`unsupported destination node: ${target}`);
  });
});

type PreflightFixture = {
  home: string;
  normal: string;
  options: Parameters<typeof inspectCandidates>[1];
  root: string;
  session: string;
  worktree: string;
};

async function makePreflightFixture(): Promise<PreflightFixture> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "candidate-preflight-test-"));
  const home = path.join(root, "home");
  const normal = path.join(home, "normal-source");
  const session = path.join(home, ".session");
  const worktree = path.join(home, "worktree");
  await fs.mkdir(home);
  await Promise.all([
    fs.mkdir(normal),
    fs.mkdir(session),
    fs.mkdir(worktree),
  ]);
  return {
    home,
    normal,
    options: {
      destinationDir: home,
      normalSourceDir: normal,
      sessionDir: session,
      worktreeRoot: worktree,
    },
    root,
    session,
    worktree,
  };
}

function candidateMap(
  entries: Array<[absolutePath: string, managedKind: CandidateTarget["managedKind"]]>,
): Map<string, CandidateTarget> {
  return new Map(
    entries.map(([absolutePath, managedKind]) => [
      path.normalize(absolutePath),
      { absolutePath: path.normalize(absolutePath), managedKind },
    ]),
  );
}

describe("resolveNormalSourceCheckout", () => {
  test("resolves the normal checkout from the shared git directory", () => {
    let invocation: { args: string[]; command: string } | undefined;
    const runner: CommandRunner = (command, args) => {
      invocation = { args, command };
      return commandResult({ stdout: Buffer.from("../normal/.git\n") });
    };

    expect(resolveNormalSourceCheckout("/repo/worktree", runner)).toBe("/repo/normal");
    expect(invocation).toEqual({
      command: "git",
      args: ["-C", "/repo/worktree", "rev-parse", "--git-common-dir"],
    });
  });

  test("uses stable context for git resolution failures", () => {
    const runner: CommandRunner = () =>
      commandResult({ status: 128, stderr: Buffer.from("not a worktree\n") });

    expect(() => resolveNormalSourceCheckout("/repo/worktree", runner)).toThrow(
      "not a worktree",
    );
  });
});

describe("stageWorktreeSource", () => {
  test("copies the source recursively into the initially absent staged directory", async () => {
    const source = await makeSourceFixture("dot_config/tool/config.toml");
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");

    await stageWorktreeSource(source, session);

    expect(
      await fs.readFile(
        path.join(session.stagedSourceDir, "dot_config", "tool", "config.toml"),
        "utf8",
      ),
    ).toBe("fixture\n");
  });

  test("preserves source symlinks instead of dereferencing them", async () => {
    const source = await makeSourceFixture("dot_target");
    await fs.symlink("dot_target", path.join(source, "dot_link"));
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");

    await stageWorktreeSource(source, session);

    expect(await fs.readlink(path.join(session.stagedSourceDir, "dot_link"))).toBe("dot_target");
  });

  test("does not overwrite an existing staged source", async () => {
    const source = await makeSourceFixture("dot_file");
    const base = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-session-test-"));
    const session = await createActiveSession(base, "/repo", "/home/u");
    await fs.mkdir(session.stagedSourceDir);
    const existingFile = path.join(session.stagedSourceDir, "dot_file");
    await fs.writeFile(existingFile, "existing\n");

    await expect(stageWorktreeSource(source, session)).rejects.toThrow("already exists");
    expect(await fs.readFile(existingFile, "utf8")).toBe("existing\n");
  });
});

test.each([
  ["run_probe", "unsupported source attribute: run_probe"],
  ["modify_dot_file", "unsupported source attribute: modify_dot_file"],
  ["exact_dot_config", "unsupported source attribute: exact_dot_config"],
  ["encrypted_dot_secret", "unsupported source attribute: encrypted_dot_secret"],
  ["remove_exact_dot_cache", "unsupported source attribute: remove_exact_dot_cache"],
  ["external_exact_dot_cache", "unsupported source attribute: external_exact_dot_cache"],
  [".chezmoiscripts/run_probe", "unsupported special source path: .chezmoiscripts"],
  [".chezmoiexternal.toml", "unsupported special source path: .chezmoiexternal.toml"],
] as const)("rejects %s", async (relativePath, message) => {
  const source = await makeSourceFixture(relativePath);
  await expect(validateStagedSource(source)).rejects.toThrow(message);
});

test("rejects exact directories", async () => {
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  await fs.mkdir(path.join(source, "exact_dot_config"));

  await expect(validateStagedSource(source)).rejects.toThrow(
    "unsupported source attribute: exact_dot_config",
  );
});

test("accepts ordinary, remove, and literal-prefixed source components", async () => {
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  for (const relativePath of [
    "dot_file",
    "remove_dot_old",
    "literal_run_probe",
    "literal_modify_dot_file",
    "literal_exact_dot_config",
    "literal_encrypted_dot_secret",
  ]) {
    await writeSourceFixture(source, relativePath);
  }

  await expect(validateStagedSource(source)).resolves.toBeUndefined();
});

test("rejects source symlinks without following them", async () => {
  const source = await makeSourceFixture("dot_target");
  await fs.symlink("dot_target", path.join(source, "dot_link"));

  await expect(validateStagedSource(source)).rejects.toThrow(
    "unsupported source symlink: dot_link",
  );
});

test("rejects a symlink used as the source root", async () => {
  const source = await makeSourceFixture("dot_file");
  const sourceLink = `${source}-link`;
  await fs.symlink(source, sourceLink, "dir");

  await expect(validateStagedSource(sourceLink)).rejects.toThrow(
    "unsupported source symlink: .",
  );
});

test("rejects special source nodes", async () => {
  if (process.platform === "win32") return;
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  const fifo = path.join(source, "dot_pipe");
  const processResult = Bun.spawn(["mkfifo", fifo], { stderr: "pipe" });
  expect(await processResult.exited).toBe(0);

  await expect(validateStagedSource(source)).rejects.toThrow(
    "unsupported source node: dot_pipe",
  );
});

async function makeSourceFixture(relativePath: string): Promise<string> {
  const source = await fs.mkdtemp(path.join(os.tmpdir(), "staged-source-test-"));
  await writeSourceFixture(source, relativePath);
  return source;
}

async function writeSourceFixture(source: string, relativePath: string): Promise<void> {
  const target = path.join(source, ...relativePath.split("/"));
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, "fixture\n");
}
