import { describe, expect, test } from "bun:test";
import { promises as fs, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  buildNonLiveCommandArgs,
  handleSpawnResult,
  ParseCliError,
  parseCliArgs,
  runLiveCliCommand,
  runWorktreeCommand,
} from "./worktree-dev.ts";
import type { ChezmoiRuntime, CommandResult } from "./worktree-runtime.ts";
import type { SessionPaths } from "./worktree-session.ts";

const realChezmoiTest = Bun.which("chezmoi") ? test : test.skip;

realChezmoiTest("prints a complete diff larger than the default subprocess buffer", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-large-diff-test-"));
  try {
    const source = path.join(root, "home");
    const destination = path.join(root, "destination");
    await fs.mkdir(path.join(source, ".shared-configs/nvim"), { recursive: true });
    await fs.mkdir(path.join(source, ".shared-configs/yazi"), { recursive: true });
    await fs.mkdir(destination);
    await fs.writeFile(path.join(source, ".chezmoiignore"), ".shared-configs\n");
    const contents = "large diff line\n".repeat(150_000) + "end of large diff\n";
    await fs.writeFile(path.join(source, "dot_large"), contents);
    const script = `
      import { runWorktreeCommand } from ${JSON.stringify(import.meta.path.replace(".test.ts", ".ts"))};
      const result = await runWorktreeCommand("diff", ${JSON.stringify(root)}, ${JSON.stringify(destination)});
      if (result.error) throw result.error;
      process.stdout.write(result.stdout);
      process.stderr.write(result.stderr);
      process.exitCode = result.status ?? 1;
    `;
    const child = Bun.spawn([process.execPath, "-e", script], {
      env: { ...process.env, PAGER: "", CHEZMOI_PAGER: "" },
      stdout: "pipe",
      stderr: "pipe",
    });
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited,
    ]);

    expect(stderr).not.toContain("ENOBUFS");
    expect(exitCode).toBe(0);
    expect(stdout.length).toBeGreaterThan(contents.length);
    expect(stdout).toContain("+end of large diff");
    expect((await fs.readdir(root)).sort()).toEqual(["destination", "home"]);
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
});

test.each([
  ["context", ["execute-template", "{{ .chezmoi.workingTree }}|{{ .chezmoi.sourceDir }}"]],
  ["diff", ["diff"]],
  ["dry-run", ["apply", "--dry-run", "--verbose"]],
  ["apply-temp", ["apply", "--verbose"]],
] as const)("builds %s arguments without --init", (command, expected) => {
  const args = buildNonLiveCommandArgs(command);
  expect(args).toEqual([...expected]);
  expect(args).not.toContain("--init");
});

test("reconciles before running chezmoi and always removes the runtime", async () => {
  const calls: string[] = [];
  const runtime: ChezmoiRuntime = {
    cacheDir: "/runtime/cache",
    configFile: "/runtime/config.toml",
    destinationDir: "/destination",
    persistentStateFile: "/runtime/state.boltdb",
    sourceDir: "/repo/home",
    worktreeRoot: "/repo",
  };
  const commandResult: CommandResult = {
    signal: null,
    status: 0,
    stderr: Buffer.alloc(0),
    stdout: Buffer.alloc(0),
  };

  const result = await runWorktreeCommand("diff", "/repo", "/destination", {
    reconcile: async () => {
      calls.push("reconcile");
      return { tools: [] };
    },
    createRuntime: async () => {
      calls.push("create-runtime");
      return runtime;
    },
    run: (_runtime, args) => {
      calls.push(`run:${args.join(",")}`);
      return commandResult;
    },
    removeRuntime: async () => {
      calls.push("remove-runtime");
    },
  });

  expect(result).toBe(commandResult);
  expect(calls).toEqual(["reconcile", "create-runtime", "run:diff", "remove-runtime"]);
});

describe("parseCliArgs", () => {
  test.each(["context", "diff", "dry-run", "apply-temp", "apply", "revert"] as const)(
    "parses the %s command positional",
    (command) => {
      expect(parseCliArgs([command])).toEqual({
        command,
        help: false,
        yes: false,
      });
    },
  );

  test("parses --yes for apply", () => {
    expect(parseCliArgs(["apply", "--yes"])).toEqual({
      command: "apply",
      help: false,
      yes: true,
    });
  });

  test("parses --yes for revert", () => {
    expect(parseCliArgs(["revert", "--yes"])).toEqual({
      command: "revert",
      help: false,
      yes: true,
    });
  });

  test("rejects --yes for a non-live command", () => {
    expect(() => parseCliArgs(["diff", "--yes"])).toThrow(
      "--yes is only valid with apply or revert",
    );
  });

  test("parses help flag", () => {
    expect(parseCliArgs(["--help"])).toEqual({
      command: undefined,
      help: true,
      yes: false,
    });
  });

  test("parses short help flag with command", () => {
    expect(parseCliArgs(["-h", "diff"])).toEqual({
      command: "diff",
      help: true,
      yes: false,
    });
  });

  test("throws ParseCliError for unknown commands", () => {
    try {
      parseCliArgs(["nope"]);
      throw new Error("expected parseCliArgs to throw");
    } catch (error) {
      expect(error).toBeInstanceOf(ParseCliError);
      expect((error as Error).message).toContain("unknown command: nope");
      expect((error as Error).message).toContain("[--help|-h]");
    }
  });

  test("throws ParseCliError for too many positionals", () => {
    try {
      parseCliArgs(["context", "diff"]);
      throw new Error("expected parseCliArgs to throw");
    } catch (error) {
      expect(error).toBeInstanceOf(ParseCliError);
      expect((error as Error).message).toContain("expected exactly one command");
    }
  });

  test("re-raises child signals instead of converting them to exit code 1", () => {
    const calls: string[] = [];

    handleSpawnResult(
      { signal: "SIGTERM", status: null },
      {
        fail: (message) => calls.push(`fail:${message}`),
        exit: (code) => calls.push(`exit:${code}`),
        raiseSignal: (signal) => calls.push(`signal:${signal}`),
      },
    );

    expect(calls).toEqual(["signal:SIGTERM"]);
  });
});

describe("live CLI dispatch", () => {
  test("dispatches apply with the resolved live options", async () => {
    const question = async () => "y";
    let appliedOptions: unknown;

    await runLiveCliCommand(
      "apply",
      {
        destinationDir: "/fake-home",
        question,
        sessionBase: "/fake-state",
        worktreeRoot: "/repo",
        yes: true,
      },
      {
        apply: async (options) => {
          appliedOptions = options;
        },
        openSession: async () => {
          throw new Error("unexpected open session");
        },
        revert: async () => {
          throw new Error("unexpected revert");
        },
      },
    );

    expect(appliedOptions).toEqual({
      destinationDir: "/fake-home",
      question,
      sessionBase: "/fake-state",
      worktreeRoot: "/repo",
      yes: true,
    });
  });

  test("opens and automatically confirms the active session for revert --yes", async () => {
    const session = fakeSession();
    const calls: string[] = [];

    await runLiveCliCommand(
      "revert",
      {
        destinationDir: "/fake-home",
        question: async () => {
          throw new Error("unexpected question");
        },
        sessionBase: "/fake-state",
        worktreeRoot: "/repo",
        yes: true,
      },
      {
        apply: async () => {
          throw new Error("unexpected apply");
        },
        openSession: async (...args) => {
          calls.push(`open:${args.join(":")}`);
          return session;
        },
        revert: async (options) => {
          calls.push(`confirmed:${await options.confirm(["M /fake-home/.target"])}`);
          expect(options.session).toBe(session);
        },
      },
    );

    expect(calls).toEqual([
      "open:/fake-state:/repo:/fake-home",
      "confirmed:true",
    ]);
  });

  test("prompts for manual revert using only status actions and paths", async () => {
    const session = fakeSession();
    const privateContents = "private contents";
    let prompt = "";

    await runLiveCliCommand(
      "revert",
      {
        destinationDir: "/fake-home",
        question: async (value) => {
          prompt = value;
          return " y ";
        },
        sessionBase: "/fake-state",
        worktreeRoot: "/repo",
        yes: false,
      },
      {
        apply: async () => {
          throw new Error("unexpected apply");
        },
        openSession: async () => session,
        revert: async (options) => {
          expect(await options.confirm(["M /fake-home/.target", "D /fake-home/.old"])).toBeTrue();
        },
      },
    );

    expect(prompt).toContain("M /fake-home/.target");
    expect(prompt).toContain("D /fake-home/.old");
    expect(prompt).not.toContain(privateContents);
  });
});

function fakeSession(): SessionPaths {
  return {
    activeDir: "/fake-state/active",
    cacheDir: "/fake-state/active/cache",
    configFile: "/fake-state/active/config.toml",
    destinationDir: "/fake-home",
    persistentStateFile: "/fake-state/active/state.boltdb",
    readyFile: "/fake-state/active/ready",
    snapshotSourceDir: "/fake-state/active/snapshot-source",
    stagedSourceDir: "/fake-state/active/staged-source",
    worktreeRoot: "/repo",
  };
}

test("defines live package scripts without changing non-live script names", () => {
  const packageJson = JSON.parse(
    readFileSync(new URL("../package.json", import.meta.url), "utf8"),
  ) as { scripts: Record<string, string> };

  expect(packageJson.scripts).toMatchObject({
    "worktree:apply": "bun run scripts/worktree-dev.ts apply",
    "worktree:apply-temp": "bun run scripts/worktree-dev.ts apply-temp",
    "worktree:context": "bun run scripts/worktree-dev.ts context",
    "worktree:diff": "bun run scripts/worktree-dev.ts diff",
    "worktree:dry-run": "bun run scripts/worktree-dev.ts dry-run",
    "worktree:revert": "bun run scripts/worktree-dev.ts revert",
  });
});
