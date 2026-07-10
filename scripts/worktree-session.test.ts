import { describe, expect, test } from "bun:test";
import { existsSync, promises as fs, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  applyPlannedChanges,
  captureSnapshot,
  confirmPaths,
  createActiveSession,
  enumerateCandidates,
  inspectCandidates,
  isPathInside,
  markSessionReady,
  openActiveSession,
  parseNulPaths,
  parseStatus,
  removeActiveSession,
  revertActiveSession,
  resolveNormalSourceCheckout,
  resolveSessionBase,
  runLiveApply,
  snapshotRuntime,
  stageWorktreeSource,
  stagedRuntime,
  validateCoverage,
  validateSafeRemovalPath,
  validateStagedSource,
  type CandidateTarget,
} from "./worktree-session.ts";
import {
  requireSuccess,
  runChezmoi,
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

describe("status output parsing", () => {
  test("parses fixed status columns and preserves spaces", () => {
    expect(parseStatus(" M /home/u/a b\n D /home/u/old\n A /home/u/new\n")).toEqual([
      { action: "M", absolutePath: "/home/u/a b" },
      { action: "D", absolutePath: "/home/u/old" },
      { action: "A", absolutePath: "/home/u/new" },
    ]);
  });

  test.each(["M /missing-column\n", " R /script\n", " X /unknown\n"])(
    "rejects malformed or executable status %s",
    (output) => expect(() => parseStatus(output)).toThrow(),
  );

  test.each([
    [" A /home/u/target\n", "A"],
    ["AD /home/u/target\n", "D"],
    ["DM /home/u/target\n", "M"],
    ["MA /home/u/target\n", "A"],
  ] as const)("accepts a known first column and parses action %s", (output, action) => {
    expect(parseStatus(output)).toEqual([{ action, absolutePath: "/home/u/target" }]);
  });

  test.each(["XM /home/u/target\n", "?A /home/u/target\n"])(
    "rejects unknown first-column status %s",
    (output) =>
      expect(() => parseStatus(output)).toThrow(
        `unsupported status first column: ${output.trimEnd()}`,
      ),
  );
});

describe("status coverage", () => {
  test.each([
    ["M", "file"],
    ["D", "file"],
    ["A", "absent"],
  ] as const)("accepts a snapshot-covered %s target with a %s baseline", (action, baselineKind) => {
    const target = "/home/u/target";
    const candidates = inspectedCandidateMap([[target, "file", baselineKind, "target"]]);
    candidates.get(target)!.snapshotCovered = true;

    expect(() => validateCoverage([{ action, absolutePath: target }], candidates)).not.toThrow();
  });

  test("accepts only creation of an absent directory without snapshot coverage", () => {
    const target = "/home/u/newdir";
    const candidates = inspectedCandidateMap([[target, "directory", "absent", "newdir"]]);

    expect(() =>
      validateCoverage([{ action: "A", absolutePath: target }], candidates),
    ).not.toThrow();
  });

  test("rejects a status path missing from the candidate inventory", () => {
    const target = "/home/u/unmanaged";

    expect(() => validateCoverage([{ action: "M", absolutePath: target }], new Map())).toThrow(
      `status path has no snapshot coverage: ${target}`,
    );
  });

  test("rejects a non-directory candidate without snapshot coverage", () => {
    const target = "/home/u/uncovered";
    const candidates = inspectedCandidateMap([[target, "file", "file", "uncovered"]]);

    expect(() => validateCoverage([{ action: "M", absolutePath: target }], candidates)).toThrow(
      `status path has no snapshot coverage: ${target}`,
    );
  });

  test.each(["M", "D"] as const)(
    "rejects %s for an existing directory",
    (action) => {
      const target = "/home/u/existing-dir";
      const candidates = inspectedCandidateMap([
        [target, "directory", "directory", "existing-dir"],
      ]);

      expect(() => validateCoverage([{ action, absolutePath: target }], candidates)).toThrow(
        `unsupported existing directory change: ${target}`,
      );
    },
  );
});

describe("apply confirmation", () => {
  test("bypasses the question when yes is set", async () => {
    let asked = false;

    expect(
      await confirmPaths([{ action: "M", absolutePath: "/home/u/file" }], true, async () => {
        asked = true;
        return "n";
      }),
    ).toBeTrue();
    expect(asked).toBeFalse();
  });

  test("accepts y and prompts with actions and paths but not contents", async () => {
    const contents = "private file contents";
    let prompt = "";

    expect(
      await confirmPaths(
        [
          { action: "M", absolutePath: "/home/u/a b" },
          { action: "D", absolutePath: "/home/u/old" },
        ],
        false,
        async (value) => {
          prompt = value;
          return " y ";
        },
      ),
    ).toBeTrue();
    expect(prompt).toContain("M /home/u/a b");
    expect(prompt).toContain("D /home/u/old");
    expect(prompt).not.toContain(contents);
  });

  test.each(["", "n"])("rejects the answer %j", async (answer) => {
    expect(
      await confirmPaths(
        [{ action: "A", absolutePath: "/home/u/new" }],
        false,
        async () => answer,
      ),
    ).toBeFalse();
  });
});

describe("explicit-target apply", () => {
  test("forces only the planned target paths while excluding unsafe categories", async () => {
    const expected = commandResult({ stdout: Buffer.from("applied") });
    let invocation: { args: string[]; command: string } | undefined;
    const runner: CommandRunner = (command, args) => {
      invocation = { args, command };
      return expected;
    };

    const result = await applyPlannedChanges(
      candidateRuntime(),
      [
        { action: "M", absolutePath: "/home/u/a b" },
        { action: "D", absolutePath: "/home/u/old" },
      ],
      runner,
    );

    expect(result).toBe(expected);
    expect(invocation?.command).toBe("chezmoi");
    expect(chezmoiCommandArgs(invocation!.args)).toEqual([
      "--force",
      "apply",
      "--exclude",
      "scripts,externals,encrypted",
      "/home/u/a b",
      "/home/u/old",
    ]);
    expect(invocation!.args).not.toContain("--keep-going");
    expect(invocation!.args).not.toContain("--init");
  });

  test("returns success without invoking chezmoi when no targets are planned", async () => {
    let invocations = 0;

    const result = await applyPlannedChanges(candidateRuntime(), [], () => {
      invocations += 1;
      return commandResult({ status: 1 });
    });

    expect(result).toEqual(commandResult());
    expect(invocations).toBe(0);
  });
});

test.each(["a*", "a?", "[a]", "{a}", "!keep", "#comment", " a", "a ", "a\r", "a\n"])(
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

describe("snapshot revert lifecycle", () => {
  test("rejects a missing active session before invoking chezmoi", async () => {
    const fixture = await makeRevertFixture(false);
    await removeActiveSession(fixture.session);
    let invocations = 0;

    await expect(
      revertActiveSession({
        automatic: true,
        confirm: async () => true,
        runner: () => {
          invocations += 1;
          return commandResult();
        },
        session: fixture.session,
      }),
    ).rejects.toMatchObject({ code: "ENOENT" });

    expect(invocations).toBe(0);
  });

  test("rejects an active session without the ready gate", async () => {
    const fixture = await makeRevertFixture(false);
    let invocations = 0;

    await expect(
      revertActiveSession({
        automatic: true,
        confirm: async () => true,
        runner: () => {
          invocations += 1;
          return commandResult();
        },
        session: fixture.session,
      }),
    ).rejects.toMatchObject({ code: "ENOENT" });

    expect(invocations).toBe(0);
    expect((await fs.stat(fixture.session.activeDir)).isDirectory()).toBeTrue();
  });

  test("retains a ready session when manual revert is refused", async () => {
    const fixture = await makeRevertFixture();
    const commands: string[][] = [];
    let confirmedLines: string[] | undefined;
    const runner: CommandRunner = (_command, args) => {
      const commandArgs = chezmoiCommandArgs(args);
      commands.push(commandArgs);
      return commandResult({
        stdout: commandArgs[0] === "status"
          ? Buffer.from(` M ${fixture.target}\n`)
          : Buffer.alloc(0),
      });
    };

    const reverting = revertActiveSession({
      automatic: false,
      confirm: async (lines) => {
        confirmedLines = lines;
        return false;
      },
      runner,
      session: fixture.session,
    });

    await expect(reverting).rejects.toThrow("revert cancelled");
    await expect(reverting).rejects.toThrow(fixture.session.activeDir);
    await expect(reverting).rejects.toThrow("pnpm run worktree:revert");
    expect(confirmedLines).toEqual([`M ${fixture.target}`]);
    expect(commands).toEqual([["status", "--path-style", "absolute"]]);
    expect((await fs.stat(fixture.session.activeDir)).isDirectory()).toBeTrue();
  });

  test("retains a ready session when snapshot apply fails", async () => {
    const fixture = await makeRevertFixture();
    const commands: string[][] = [];
    const runner: CommandRunner = (_command, args) => {
      const commandArgs = chezmoiCommandArgs(args);
      commands.push(commandArgs);
      if (commandArgs[0] === "status") return commandResult();
      return commandResult({ status: 1, stderr: Buffer.from("snapshot apply failed\n") });
    };

    const reverting = revertActiveSession({
      automatic: true,
      confirm: async () => true,
      runner,
      session: fixture.session,
    });

    await expect(reverting).rejects.toThrow("snapshot apply failed");
    await expect(reverting).rejects.toThrow(fixture.session.activeDir);
    await expect(reverting).rejects.toThrow("pnpm run worktree:revert");
    expect(commands).toEqual([
      ["status", "--path-style", "absolute"],
      ["--force", "apply"],
    ]);
    expect((await fs.stat(fixture.session.activeDir)).isDirectory()).toBeTrue();
  });

  test("retains a ready session when snapshot verification fails", async () => {
    const fixture = await makeRevertFixture();
    const commands: string[][] = [];
    const runner: CommandRunner = (_command, args) => {
      const commandArgs = chezmoiCommandArgs(args);
      commands.push(commandArgs);
      if (commandArgs[0] === "verify") {
        return commandResult({ status: 1, stderr: Buffer.from("snapshot verify failed\n") });
      }
      return commandResult();
    };

    const reverting = revertActiveSession({
      automatic: true,
      confirm: async () => true,
      runner,
      session: fixture.session,
    });

    await expect(reverting).rejects.toThrow("snapshot verify failed");
    await expect(reverting).rejects.toThrow(fixture.session.activeDir);
    await expect(reverting).rejects.toThrow("pnpm run worktree:revert");
    expect(commands).toEqual([
      ["status", "--path-style", "absolute"],
      ["--force", "apply"],
      ["verify"],
    ]);
    expect((await fs.stat(fixture.session.activeDir)).isDirectory()).toBeTrue();
  });

  test("deletes a ready session only after snapshot apply and verify succeed", async () => {
    const fixture = await makeRevertFixture();
    const commands: string[][] = [];
    const runner: CommandRunner = (_command, args) => {
      const commandArgs = chezmoiCommandArgs(args);
      commands.push(commandArgs);
      return commandResult();
    };

    await revertActiveSession({
      automatic: true,
      confirm: async () => false,
      runner,
      session: fixture.session,
    });

    expect(commands).toEqual([
      ["status", "--path-style", "absolute"],
      ["--force", "apply"],
      ["verify"],
    ]);
    expect(commands.flat()).not.toContain("--init");
    expect(commands.flat()).not.toContain("--keep-going");
    await expect(fs.stat(fixture.session.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("a second revert converges after cleanup was interrupted", async () => {
    const fixture = await makeRevertFixture();
    const commands: string[][] = [];
    const originalRm = fs.rm.bind(fs);
    let cleanupAttempts = 0;
    fs.rm = (async (target, options) => {
      cleanupAttempts += 1;
      if (cleanupAttempts === 1) throw new Error("cleanup interrupted");
      await originalRm(target, options);
    }) as typeof fs.rm;

    const runner: CommandRunner = (_command, args) => {
      commands.push(chezmoiCommandArgs(args));
      return commandResult();
    };

    try {
      const firstRevert = revertActiveSession({
        automatic: true,
        confirm: async () => true,
        runner,
        session: fixture.session,
      });
      await expect(firstRevert).rejects.toThrow("cleanup interrupted");
      await expect(firstRevert).rejects.toThrow(fixture.session.activeDir);
      await expect(firstRevert).rejects.toThrow("pnpm run worktree:revert");
      expect((await fs.stat(fixture.session.activeDir)).isDirectory()).toBeTrue();

      await revertActiveSession({
        automatic: true,
        confirm: async () => true,
        runner,
        session: fixture.session,
      });
    } finally {
      fs.rm = originalRm;
    }

    expect(cleanupAttempts).toBe(2);
    expect(commands).toEqual([
      ["status", "--path-style", "absolute"],
      ["--force", "apply"],
      ["verify"],
      ["status", "--path-style", "absolute"],
      ["--force", "apply"],
      ["verify"],
    ]);
    await expect(fs.stat(fixture.session.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
  });
});

async function makeRevertFixture(ready = true) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "snapshot-revert-test-"));
  const home = path.join(root, "home");
  await fs.mkdir(home);
  const session = await createActiveSession(path.join(root, "state"), "/repo", home);
  if (ready) await markSessionReady(session);
  return { session, target: path.join(home, ".target") };
}

describe("live apply orchestration", () => {
  test("automatically reverts a failed apply after a fake-home mutation", async () => {
    const fixture = await makeLiveApplyFixture();
    let prompt = "";
    const live = createLiveRunner(fixture, {
      applyResult: commandResult({
        status: 1,
        stderr: Buffer.from("staged apply failed\n"),
      }),
      onSnapshotApply: () => writeFileSync(fixture.target, "before\n"),
      onStagedApply: () => writeFileSync(fixture.target, "after\n"),
    });

    await expect(
      runLiveApply({
        destinationDir: fixture.home,
        question: async (value) => {
          live.events.push("confirm");
          prompt = value;
          return "y";
        },
        runner: live.runner,
        sessionBase: fixture.sessionBase,
        worktreeRoot: fixture.worktree,
        yes: false,
      }),
    ).rejects.toThrow("staged apply failed");

    expect(readFileSync(fixture.target, "utf8")).toBe("before\n");
    expect(prompt).toContain(`M ${fixture.target}`);
    expect(prompt).not.toContain("before");
    expect(prompt).not.toContain("after");
    expect(live.events).toEqual([
      "enumerate:dirs",
      "enumerate:files",
      "enumerate:symlinks",
      "enumerate:remove",
      "resolve-normal",
      "capture",
      "capture-verify",
      "status",
      "confirm",
      "apply",
      "revert-status",
      "revert-apply",
      "revert-verify",
    ]);
    await expect(fs.stat(fixture.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("removes an incomplete session when capture fails before ready", async () => {
    const fixture = await makeLiveApplyFixture();
    let asked = false;
    const live = createLiveRunner(fixture, {
      captureResult: commandResult({
        status: 1,
        stderr: Buffer.from("capture failed\n"),
      }),
    });

    await expect(
      runLiveApply({
        destinationDir: fixture.home,
        question: async () => {
          asked = true;
          return "y";
        },
        runner: live.runner,
        sessionBase: fixture.sessionBase,
        worktreeRoot: fixture.worktree,
        yes: false,
      }),
    ).rejects.toThrow("capture failed");

    expect(asked).toBeFalse();
    expect(readFileSync(fixture.target, "utf8")).toBe("before\n");
    expect(live.events).toEqual([
      "enumerate:dirs",
      "enumerate:files",
      "enumerate:symlinks",
      "enumerate:remove",
      "resolve-normal",
      "capture",
    ]);
    expect(live.events).not.toContain("revert-status");
    await expect(fs.stat(fixture.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("retains the ready session when automatic revert also fails", async () => {
    const fixture = await makeLiveApplyFixture();
    const live = createLiveRunner(fixture, {
      applyResult: commandResult({ status: 1, stderr: Buffer.from("staged apply failed\n") }),
      onStagedApply: () => writeFileSync(fixture.target, "after\n"),
      snapshotApplyResult: commandResult({
        status: 1,
        stderr: Buffer.from("snapshot recovery failed\n"),
      }),
    });

    const applying = runLiveApply({
      destinationDir: fixture.home,
      question: async () => "y",
      runner: live.runner,
      sessionBase: fixture.sessionBase,
      worktreeRoot: fixture.worktree,
      yes: true,
    });

    await expect(applying).rejects.toThrow("apply and automatic revert failed");
    await expect(applying).rejects.toThrow(fixture.activeDir);
    await expect(applying).rejects.toThrow("pnpm run worktree:revert");
    expect(readFileSync(fixture.target, "utf8")).toBe("after\n");
    expect(live.events.at(-1)).toBe("revert-apply");
    expect(await fs.readFile(path.join(fixture.activeDir, "ready"), "utf8")).toBe("ready\n");
    await fs.rm(fixture.activeDir, { force: true, recursive: true });
  });

  test("removes a ready session when path confirmation is cancelled", async () => {
    const fixture = await makeLiveApplyFixture();
    const live = createLiveRunner(fixture);

    await runLiveApply({
      destinationDir: fixture.home,
      question: async () => {
        live.events.push("confirm");
        return "n";
      },
      runner: live.runner,
      sessionBase: fixture.sessionBase,
      worktreeRoot: fixture.worktree,
      yes: false,
    });

    expect(live.events.at(-2)).toBe("status");
    expect(live.events.at(-1)).toBe("confirm");
    expect(live.events).not.toContain("apply");
    expect(live.events).not.toContain("revert-status");
    expect(readFileSync(fixture.target, "utf8")).toBe("before\n");
    await expect(fs.stat(fixture.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("removes a ready session when coverage validation fails", async () => {
    const fixture = await makeLiveApplyFixture();
    const unmanaged = path.join(fixture.home, ".unmanaged");
    let asked = false;
    const live = createLiveRunner(fixture, { plannedTarget: unmanaged });

    await expect(
      runLiveApply({
        destinationDir: fixture.home,
        question: async () => {
          asked = true;
          return "y";
        },
        runner: live.runner,
        sessionBase: fixture.sessionBase,
        worktreeRoot: fixture.worktree,
        yes: false,
      }),
    ).rejects.toThrow(`status path has no snapshot coverage: ${unmanaged}`);

    expect(asked).toBeFalse();
    expect(live.events.at(-1)).toBe("status");
    expect(live.events).not.toContain("apply");
    await expect(fs.stat(fixture.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("removes an empty-plan session without prompting or unscoped apply", async () => {
    const fixture = await makeLiveApplyFixture();
    let asked = false;
    const live = createLiveRunner(fixture, {
      managedTarget: null,
      plannedTarget: null,
    });

    await runLiveApply({
      destinationDir: fixture.home,
      question: async () => {
        asked = true;
        return "y";
      },
      runner: live.runner,
      sessionBase: fixture.sessionBase,
      worktreeRoot: fixture.worktree,
      yes: false,
    });

    expect(asked).toBeFalse();
    expect(live.events).not.toContain("apply");
    expect(live.events).not.toContain("revert-status");
    expect(readFileSync(fixture.target, "utf8")).toBe("before\n");
    await expect(fs.stat(fixture.activeDir)).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("retains the ready session after a successful explicit-path apply", async () => {
    const fixture = await makeLiveApplyFixture();
    const live = createLiveRunner(fixture, {
      onStagedApply: () => writeFileSync(fixture.target, "after\n"),
    });

    await runLiveApply({
      destinationDir: fixture.home,
      question: async () => "n",
      runner: live.runner,
      sessionBase: fixture.sessionBase,
      worktreeRoot: fixture.worktree,
      yes: true,
    });

    expect(readFileSync(fixture.target, "utf8")).toBe("after\n");
    expect(live.events.at(-1)).toBe("apply");
    expect(await fs.readFile(path.join(fixture.activeDir, "ready"), "utf8")).toBe("ready\n");
    await fs.rm(fixture.activeDir, { force: true, recursive: true });
  });
});

type LiveApplyFixture = {
  activeDir: string;
  home: string;
  normalSource: string;
  sessionBase: string;
  target: string;
  worktree: string;
};

async function makeLiveApplyFixture(): Promise<LiveApplyFixture> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "live-apply-test-"));
  const home = path.join(root, "fake-home");
  const normalSource = path.join(root, "normal-source");
  const sessionBase = path.join(root, "state");
  const worktree = path.join(root, "worktree");
  const source = path.join(worktree, "home");
  const target = path.join(home, ".target");
  await Promise.all([
    fs.mkdir(home),
    fs.mkdir(normalSource),
    fs.mkdir(path.join(source, ".shared-configs", "nvim"), { recursive: true }),
    fs.mkdir(path.join(source, ".shared-configs", "yazi"), { recursive: true }),
  ]);
  await Promise.all([
    fs.writeFile(target, "before\n"),
    fs.writeFile(path.join(source, "dot_target"), "after\n"),
    fs.writeFile(path.join(source, ".shared-configs", "nvim", "init.lua"), "fixture\n"),
  ]);
  return {
    activeDir: path.join(sessionBase, "active"),
    home,
    normalSource,
    sessionBase,
    target,
    worktree,
  };
}

function createLiveRunner(
  fixture: LiveApplyFixture,
  options: {
    applyResult?: CommandResult;
    captureResult?: CommandResult;
    managedTarget?: string | null;
    onSnapshotApply?: () => void;
    onStagedApply?: () => void;
    plannedTarget?: string | null;
    snapshotApplyResult?: CommandResult;
  } = {},
): { events: string[]; runner: CommandRunner } {
  const events: string[] = [];
  const managedTarget = options.managedTarget === undefined ? fixture.target : options.managedTarget;
  const plannedTarget = options.plannedTarget === undefined ? fixture.target : options.plannedTarget;
  const stagedSource = path.join(fixture.activeDir, "staged-source");
  const snapshotSource = path.join(fixture.activeDir, "snapshot-source");

  const runner: CommandRunner = (command, args) => {
    if (command === "git") {
      events.push("resolve-normal");
      expect(existsSync(fixture.activeDir)).toBeTrue();
      return commandResult({
        stdout: Buffer.from(`${path.join(fixture.normalSource, ".git")}\n`),
      });
    }

    expect(command).toBe("chezmoi");
    const sourceDir = args[args.indexOf("--source") + 1];
    const commandArgs = chezmoiCommandArgs(args);
    const verb = commandArgs[0];

    if (verb === "managed") {
      const include = commandArgs[commandArgs.indexOf("--include") + 1];
      events.push(`enumerate:${include}`);
      if (include === "dirs") {
        const wrapper = path.join("dot_config", "nvim", "init.lua.tmpl");
        expect(readFileSync(path.join(fixture.worktree, "home", wrapper), "utf8")).toContain(
          ".shared-configs/nvim/init.lua",
        );
        expect(readFileSync(path.join(stagedSource, wrapper), "utf8")).toContain(
          ".shared-configs/nvim/init.lua",
        );
        expect(existsSync(path.join(fixture.activeDir, "ready"))).toBeFalse();
      }
      return commandResult({
        stdout: Buffer.from(include === "files" && managedTarget !== null ? `${managedTarget}\0` : ""),
      });
    }

    if (sourceDir === snapshotSource && verb === "add") {
      events.push("capture");
      expect(readFileSync(fixture.target, "utf8")).toBe("before\n");
      return options.captureResult ?? commandResult();
    }

    if (sourceDir === snapshotSource && verb === "verify") {
      const reverting = existsSync(path.join(fixture.activeDir, "ready"));
      events.push(reverting ? "revert-verify" : "capture-verify");
      expect(readFileSync(fixture.target, "utf8")).toBe("before\n");
      return commandResult();
    }

    if (sourceDir === stagedSource && verb === "status") {
      events.push("status");
      expect(existsSync(path.join(fixture.activeDir, "ready"))).toBeTrue();
      expect(commandArgs).toEqual([
        "status",
        "--path-style",
        "absolute",
        "--exclude",
        "scripts,externals,encrypted",
      ]);
      return commandResult({
        stdout: Buffer.from(plannedTarget === null ? "" : ` M ${plannedTarget}\n`),
      });
    }

    if (sourceDir === stagedSource && verb === "--force") {
      events.push("apply");
      expect(commandArgs).toEqual([
        "--force",
        "apply",
        "--exclude",
        "scripts,externals,encrypted",
        fixture.target,
      ]);
      expect(commandArgs).not.toContain("--init");
      expect(commandArgs).not.toContain("--keep-going");
      options.onStagedApply?.();
      return options.applyResult ?? commandResult();
    }

    if (sourceDir === snapshotSource && verb === "status") {
      events.push("revert-status");
      return commandResult({ stdout: Buffer.from(` M ${fixture.target}\n`) });
    }

    if (sourceDir === snapshotSource && verb === "--force") {
      events.push("revert-apply");
      expect(commandArgs).toEqual(["--force", "apply"]);
      options.onSnapshotApply?.();
      return options.snapshotApplyResult ?? commandResult();
    }

    throw new Error(`unexpected live command: ${sourceDir} :: ${commandArgs.join(" ")}`);
  };

  return { events, runner };
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

describe("snapshot capture", () => {
  test("captures existing targets, records sorted absences, and verifies last", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "snapshot-capture-test-"));
    const home = path.join(root, "home");
    await fs.mkdir(home);
    const session = await createActiveSession(path.join(root, "state"), "/repo", home);
    const existingFile = path.join(home, ".existing");
    const existingLink = path.join(home, ".link");
    const absentZ = path.join(home, ".z-created");
    const absentA = path.join(home, ".a-created");
    const absentLink = path.join(home, ".created-link");
    const absentRemove = path.join(home, ".removed-already");
    const existingDirectory = path.join(home, ".config");
    const absentDirectory = path.join(home, ".newdir");
    const candidates = inspectedCandidateMap([
      [existingFile, "file", "file", ".existing"],
      [existingLink, "symlink", "symlink", ".link"],
      [absentZ, "file", "absent", ".z-created"],
      [absentA, "file", "absent", ".a-created"],
      [absentLink, "symlink", "absent", ".created-link"],
      [absentRemove, "remove", "absent", ".removed-already"],
      [existingDirectory, "directory", "directory", ".config"],
      [absentDirectory, "directory", "absent", ".newdir"],
    ]);
    const invocations: Array<{ args: string[]; command: string }> = [];
    const runner: CommandRunner = (command, args) => {
      invocations.push({ args, command });
      return commandResult();
    };

    await captureSnapshot(session, candidates, runner);

    expect(
      invocations.map(({ args, command }) => ({ command, args: chezmoiCommandArgs(args) })),
    ).toEqual([
      { command: "chezmoi", args: ["add", existingFile] },
      { command: "chezmoi", args: ["add", existingLink] },
      { command: "chezmoi", args: ["verify"] },
    ]);
    expect(invocations.every(({ args }) => !args.includes("--init"))).toBeTrue();
    expect(invocations.every(({ args }) => !args.includes("--keep-going"))).toBeTrue();
    const manifest = path.join(session.snapshotSourceDir, ".chezmoiremove");
    expect(await fs.readFile(manifest, "utf8")).toBe(
      ".a-created\n.created-link\n.removed-already\n.z-created\n",
    );
    expect((await fs.stat(manifest)).mode & 0o777).toBe(0o600);
    await expect(fs.stat(`${manifest}.tmp`)).rejects.toMatchObject({ code: "ENOENT" });
    await expect(fs.stat(session.readyFile)).rejects.toMatchObject({ code: "ENOENT" });
    for (const target of [
      existingFile,
      existingLink,
      absentZ,
      absentA,
      absentLink,
      absentRemove,
    ]) {
      expect(candidates.get(target)?.snapshotCovered).toBeTrue();
    }
    expect(candidates.get(existingDirectory)?.snapshotCovered).toBeUndefined();
    expect(candidates.get(absentDirectory)?.snapshotCovered).toBeUndefined();
  });

  test("does not mark an existing target covered when add fails", async () => {
    const fixture = await makeCaptureFixture();
    const target = path.join(fixture.session.destinationDir, ".existing");
    const candidates = inspectedCandidateMap([[target, "file", "file", ".existing"]]);
    const runner: CommandRunner = () =>
      commandResult({ status: 1, stderr: Buffer.from("snapshot add failed\n") });

    await expect(captureSnapshot(fixture.session, candidates, runner)).rejects.toThrow(
      "snapshot add failed",
    );

    expect(candidates.get(target)?.snapshotCovered).toBeUndefined();
  });

  test("does not mark an absent target covered when the manifest write fails", async () => {
    const fixture = await makeCaptureFixture();
    const target = path.join(fixture.session.destinationDir, ".created");
    const candidates = inspectedCandidateMap([[target, "file", "absent", ".created"]]);
    await fs.rm(fixture.session.snapshotSourceDir, { recursive: true });
    let invocations = 0;

    await expect(
      captureSnapshot(fixture.session, candidates, () => {
        invocations += 1;
        return commandResult();
      }),
    ).rejects.toMatchObject({ code: "ENOENT" });

    expect(invocations).toBe(0);
    expect(candidates.get(target)?.snapshotCovered).toBeUndefined();
  });

  test("rejects an unsafe absence before writing or verifying", async () => {
    const fixture = await makeCaptureFixture();
    const target = path.join(fixture.session.destinationDir, ".created");
    const candidates = inspectedCandidateMap([[target, "file", "absent", "bad*"]]);
    let invocations = 0;

    await expect(
      captureSnapshot(fixture.session, candidates, () => {
        invocations += 1;
        return commandResult();
      }),
    ).rejects.toThrow("unsafe removal path: bad*");

    expect(invocations).toBe(0);
    expect(candidates.get(target)?.snapshotCovered).toBeUndefined();
  });

  test("throws on verification failure without marking the session ready", async () => {
    const fixture = await makeCaptureFixture();
    const runner: CommandRunner = () =>
      commandResult({ status: 1, stderr: Buffer.from("snapshot mismatch\n") });

    await expect(captureSnapshot(fixture.session, new Map(), runner)).rejects.toThrow(
      "snapshot mismatch",
    );
    await expect(fs.stat(fixture.session.readyFile)).rejects.toMatchObject({ code: "ENOENT" });
  });
});

const realChezmoiTest = Bun.which("chezmoi") === null ? test.skip : test;

realChezmoiTest("round-trips a fake home through a real chezmoi snapshot", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "snapshot-round-trip-test-"));
  const home = path.join(root, "home");
  const normalSource = path.join(root, "normal-source");
  const worktree = path.join(root, "worktree");
  await Promise.all([fs.mkdir(home), fs.mkdir(normalSource), fs.mkdir(worktree)]);
  const session = await createActiveSession(path.join(root, "state"), worktree, home);
  const modified = path.join(home, ".modified");
  const empty = path.join(home, ".empty");
  const privateFile = path.join(home, ".private");
  const link = path.join(home, ".link");
  const removed = path.join(home, ".removed");
  const spaced = path.join(home, ".with space");
  const created = path.join(home, ".created");
  const createdLink = path.join(home, ".created-link");
  const alreadyAbsent = path.join(home, ".already-absent");
  const existingDirectory = path.join(home, ".config");
  const absentDirectory = path.join(home, ".newdir");
  await Promise.all([
    fs.writeFile(modified, "before\n"),
    fs.writeFile(empty, ""),
    fs.writeFile(privateFile, "private-before\n", { mode: 0o600 }),
    fs.symlink("before-target", link),
    fs.writeFile(removed, "removed-before\n"),
    fs.writeFile(spaced, "space-before\n"),
    fs.mkdir(existingDirectory),
  ]);
  await fs.chmod(privateFile, 0o600);
  const candidates = candidateMap([
    [modified, "file"],
    [empty, "file"],
    [privateFile, "file"],
    [link, "symlink"],
    [removed, "remove"],
    [spaced, "file"],
    [created, "file"],
    [createdLink, "symlink"],
    [alreadyAbsent, "remove"],
    [existingDirectory, "directory"],
    [absentDirectory, "directory"],
  ]);
  await inspectCandidates(candidates, {
    destinationDir: home,
    normalSourceDir: normalSource,
    sessionDir: session.activeDir,
    worktreeRoot: worktree,
  });

  await captureSnapshot(session, candidates);

  await fs.writeFile(modified, "after\n");
  await fs.writeFile(empty, "after\n");
  await fs.writeFile(privateFile, "private-after\n", { mode: 0o644 });
  await fs.chmod(privateFile, 0o644);
  await fs.rm(link);
  await fs.symlink("after-target", link);
  await fs.rm(removed);
  await fs.writeFile(spaced, "space-after\n");
  await fs.writeFile(created, "created-after\n");
  await fs.symlink("created-target", createdLink);
  await fs.writeFile(alreadyAbsent, "created-after\n");

  requireSuccess(
    runChezmoi(snapshotRuntime(session), ["--force", "apply"]),
    "restore fake home",
  );

  expect(await fs.readFile(modified, "utf8")).toBe("before\n");
  expect(await fs.readFile(empty, "utf8")).toBe("");
  expect(await fs.readFile(privateFile, "utf8")).toBe("private-before\n");
  expect((await fs.stat(privateFile)).mode & 0o777).toBe(0o600);
  expect(await fs.readlink(link)).toBe("before-target");
  expect(await fs.readFile(removed, "utf8")).toBe("removed-before\n");
  expect(await fs.readFile(spaced, "utf8")).toBe("space-before\n");
  await expect(fs.lstat(created)).rejects.toMatchObject({ code: "ENOENT" });
  await expect(fs.lstat(createdLink)).rejects.toMatchObject({ code: "ENOENT" });
  await expect(fs.lstat(alreadyAbsent)).rejects.toMatchObject({ code: "ENOENT" });
  await expect(fs.stat(session.readyFile)).rejects.toMatchObject({ code: "ENOENT" });
  expect(candidates.get(existingDirectory)?.snapshotCovered).toBeUndefined();
  expect(candidates.get(absentDirectory)?.snapshotCovered).toBeUndefined();
}, 30_000);

realChezmoiTest("applies a nested file through its absent parent in a fake home", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "nested-parent-apply-test-"));
  const home = path.join(root, "home");
  const normalSource = path.join(root, "normal-source");
  const worktree = path.join(root, "worktree");
  await Promise.all([fs.mkdir(home), fs.mkdir(normalSource), fs.mkdir(worktree)]);
  const session = await createActiveSession(path.join(root, "state"), worktree, home);
  const sourceDirectory = path.join(session.stagedSourceDir, "dot_newdir");
  const parent = path.join(home, ".newdir");
  const child = path.join(parent, "file");
  await fs.mkdir(sourceDirectory, { recursive: true });
  await fs.writeFile(path.join(sourceDirectory, "file"), "nested content\n");

  const candidates = await enumerateCandidates(stagedRuntime(session));
  await inspectCandidates(candidates, {
    destinationDir: home,
    normalSourceDir: normalSource,
    sessionDir: session.activeDir,
    worktreeRoot: worktree,
  });
  await captureSnapshot(session, candidates);

  const status = requireSuccess(
    runChezmoi(stagedRuntime(session), [
      "status",
      "--path-style",
      "absolute",
      "--exclude",
      "scripts,externals,encrypted",
    ]),
    "inspect nested staged status",
  );
  const planned = parseStatus(status.stdout.toString("utf8"));

  expect(planned).toHaveLength(2);
  expect(planned).toContainEqual({ action: "A", absolutePath: parent });
  expect(planned).toContainEqual({ action: "A", absolutePath: child });
  expect(() => validateCoverage(planned, candidates)).not.toThrow();

  requireSuccess(
    await applyPlannedChanges(stagedRuntime(session), planned),
    "apply nested staged paths",
  );
  expect(await fs.readFile(child, "utf8")).toBe("nested content\n");
}, 30_000);

type CaptureFixture = {
  session: Awaited<ReturnType<typeof createActiveSession>>;
};

async function makeCaptureFixture(): Promise<CaptureFixture> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "snapshot-capture-test-"));
  const home = path.join(root, "home");
  await fs.mkdir(home);
  return {
    session: await createActiveSession(path.join(root, "state"), "/repo", home),
  };
}

function inspectedCandidateMap(
  entries: Array<
    [
      absolutePath: string,
      managedKind: CandidateTarget["managedKind"],
      baselineKind: NonNullable<CandidateTarget["baselineKind"]>,
      relativePath: string,
    ]
  >,
): Map<string, CandidateTarget> {
  return new Map(
    entries.map(([absolutePath, managedKind, baselineKind, relativePath]) => [
      path.normalize(absolutePath),
      { absolutePath: path.normalize(absolutePath), baselineKind, managedKind, relativePath },
    ]),
  );
}

function chezmoiCommandArgs(args: string[]): string[] {
  return args.slice(12);
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
