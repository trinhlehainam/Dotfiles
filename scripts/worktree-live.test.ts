import { afterEach, describe, expect, test } from "bun:test";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import { runCommand, type CommandRunner } from "./worktree-runtime.ts";
import {
  createActiveSession,
  openActiveSession,
  revertActiveSession,
  runLiveApply,
} from "./worktree-session.ts";

const realTest = Bun.which("chezmoi") && Bun.which("git") ? test : test.skip;
const posixTest = process.platform === "win32" ? test.skip : realTest;
const roots: string[] = [];

afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("worktree apply and revert with real chezmoi", () => {
  posixTest("restores file contents, supported modes, symlinks, and absent targets", async () => {
    const fixture = await makeFixture({
      dot_binary: "changed\n",
      empty_dot_empty: "changed\n",
      private_dot_private: "changed\n",
      executable_dot_executable: "changed\n",
      symlink_dot_link: "after-target",
      dot_created: "created\n",
      symlink_dot_created_link: "created-target",
      remove_dot_removed: "",
      "dot_with space": "changed\n",
    });
    const binary = Buffer.from([0, 1, 255, 13, 10]);
    await writeTree(fixture.home, {
      ".binary": binary,
      ".empty": "",
      ".private": "private baseline\n",
      ".executable": "executable baseline\n",
      ".removed": "removed baseline\n",
      ".with space": "space baseline\n",
      ".unrelated": "untouched\n",
    });
    await fs.chmod(path.join(fixture.home, ".private"), 0o600);
    await fs.chmod(path.join(fixture.home, ".executable"), 0o755);
    await fs.symlink("before-target", path.join(fixture.home, ".link"));

    await apply(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".binary"), "utf8")).toBe("changed\n");
    expect(await fs.readlink(path.join(fixture.home, ".link"))).toBe("after-target");
    await expectAbsent(path.join(fixture.home, ".removed"));
    await revert(fixture);

    expect(await fs.readFile(path.join(fixture.home, ".binary"))).toEqual(binary);
    expect(await fs.readFile(path.join(fixture.home, ".empty"), "utf8")).toBe("");
    expect(await fs.readFile(path.join(fixture.home, ".private"), "utf8"))
      .toBe("private baseline\n");
    expect((await fs.stat(path.join(fixture.home, ".private"))).mode & 0o777).toBe(0o600);
    expect(await fs.readFile(path.join(fixture.home, ".executable"), "utf8"))
      .toBe("executable baseline\n");
    expect((await fs.stat(path.join(fixture.home, ".executable"))).mode & 0o777).toBe(0o755);
    expect(await fs.readlink(path.join(fixture.home, ".link"))).toBe("before-target");
    expect(await fs.readFile(path.join(fixture.home, ".removed"), "utf8"))
      .toBe("removed baseline\n");
    expect(await fs.readFile(path.join(fixture.home, ".with space"), "utf8"))
      .toBe("space baseline\n");
    expect(await fs.readFile(path.join(fixture.home, ".unrelated"), "utf8")).toBe("untouched\n");
    await expectAbsent(path.join(fixture.home, ".created"));
    await expectAbsent(path.join(fixture.home, ".created_link"));
    await expectAbsent(fixture.activeDir);
  });

  realTest("removes newly created nested directories when reverting", async () => {
    const fixture = await makeFixture({ "dot_newdir/nested/config": "worktree\n" });

    await apply(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".newdir/nested/config"), "utf8"))
      .toBe("worktree\n");
    await revert(fixture);

    await expectAbsent(path.join(fixture.home, ".newdir"));
    await expectAbsent(fixture.activeDir);
  });

  posixTest("restores empty directories and directory modes without deleting siblings", async () => {
    const fixture = await makeFixture({
      "dot_config/managed": "worktree\n",
      "dot_empty-dir": null,
    });
    await writeTree(fixture.home, {
      ".config/unrelated": "untouched\n",
      ".empty-dir": null,
    });
    await fs.chmod(path.join(fixture.home, ".config"), 0o700);
    await fs.chmod(path.join(fixture.home, ".empty-dir"), 0o700);

    await apply(fixture);
    expect((await fs.stat(path.join(fixture.home, ".config"))).mode & 0o777).toBe(0o755);
    await fs.rmdir(path.join(fixture.home, ".empty-dir"));
    await revert(fixture);

    expect((await fs.stat(path.join(fixture.home, ".config"))).mode & 0o777).toBe(0o700);
    expect((await fs.stat(path.join(fixture.home, ".empty-dir"))).mode & 0o777).toBe(0o700);
    expect(await fs.readdir(path.join(fixture.home, ".empty-dir"))).toEqual([]);
    expect(await fs.readFile(path.join(fixture.home, ".config/unrelated"), "utf8"))
      .toBe("untouched\n");
    await expectAbsent(path.join(fixture.home, ".config/managed"));
  });

  realTest("retains recovery when a new directory contains an unknown file, then retries", async () => {
    const fixture = await makeFixture({ "dot_newdir/nested/config": "worktree\n" });
    await apply(fixture);
    const unknown = path.join(fixture.home, ".newdir/user-file");
    await fs.writeFile(unknown, "keep me\n");

    await expect(revert(fixture)).rejects.toThrow();

    expect(await fs.readFile(unknown, "utf8")).toBe("keep me\n");
    expect(await fs.readFile(path.join(fixture.home, ".newdir/nested/config"), "utf8"))
      .toBe("worktree\n");
    expect((await fs.stat(fixture.activeDir)).isDirectory()).toBeTrue();
    await fs.rm(unknown);
    await revert(fixture);
    await expectAbsent(path.join(fixture.home, ".newdir"));
    await expectAbsent(fixture.activeDir);
  });

  posixTest("rejects a changed symlink ancestor before revert can write outside destination", async () => {
    const fixture = await makeFixture({ "dot_config/app/config": "worktree\n" });
    await writeTree(fixture.home, { ".config/app/config": "baseline\n" });
    const outside = path.join(fixture.root, "outside");
    await writeTree(outside, { "app/config": "outside untouched\n" });
    await apply(fixture);
    const savedConfig = path.join(fixture.root, "saved-config");
    await fs.rename(path.join(fixture.home, ".config"), savedConfig);
    await fs.symlink(outside, path.join(fixture.home, ".config"), "dir");

    await expect(revert(fixture)).rejects.toThrow();

    expect(await fs.readFile(path.join(outside, "app/config"), "utf8"))
      .toBe("outside untouched\n");
    expect(await fs.readFile(path.join(savedConfig, "app/config"), "utf8"))
      .toBe("worktree\n");
    expect((await fs.stat(fixture.activeDir)).isDirectory()).toBeTrue();
    await fs.unlink(path.join(fixture.home, ".config"));
    await fs.rename(savedConfig, path.join(fixture.home, ".config"));
    await revert(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".config/app/config"), "utf8"))
      .toBe("baseline\n");
  });

  posixTest("rejects an unsupported baseline mode before changing the destination", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n", { mode: 0o640 });
    await fs.chmod(target, 0o640);

    await expect(apply(fixture)).rejects.toThrow();

    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    expect((await fs.stat(target)).mode & 0o777).toBe(0o640);
    await expectAbsent(fixture.activeDir);
  });

  realTest("rejects a second apply and preserves the first session's baseline", async () => {
    const fixture = await makeFixture({ dot_configfile: "first worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    await fs.writeFile(path.join(fixture.source, "dot_configfile"), "second worktree\n");

    await expect(apply(fixture)).rejects.toThrow("active worktree test session already exists");

    expect(await fs.readFile(target, "utf8")).toBe("first worktree\n");
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(fixture.activeDir);
  });

  realTest("reserves the session before starting apply", async () => {
    const fixture = await makeFixture({ dot_created: "worktree\n" });
    await createActiveSession(fixture.sessionBase, fixture.worktree, fixture.home);

    await expect(apply(fixture)).rejects.toThrow("active worktree test session already exists");

    await expectAbsent(path.join(fixture.home, ".created"));
    expect((await fs.stat(fixture.activeDir)).isDirectory()).toBeTrue();
  });

  realTest("automatically restores the baseline after apply reports failure", async () => {
    const fixture = await makeFixture({
      dot_configfile: "worktree\n",
      "dot_newdir/nested/config": "created\n",
    });
    await fs.writeFile(path.join(fixture.home, ".configfile"), "baseline\n");

    await expect(apply(fixture, { runner: failAfterApply(fixture) }))
      .rejects.toThrow("injected apply failure");

    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("baseline\n");
    await expectAbsent(path.join(fixture.home, ".newdir"));
    await expectAbsent(fixture.activeDir);
  });

  realTest("keeps the snapshot when automatic recovery fails and allows manual retry", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");

    await expect(apply(fixture, { runner: failAfterApply(fixture, true) }))
      .rejects.toThrow("apply and automatic revert failed");

    expect(await fs.readFile(target, "utf8")).toBe("worktree\n");
    expect((await fs.stat(fixture.activeDir)).isDirectory()).toBeTrue();
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(fixture.activeDir);
  });

  realTest("cancels apply before changing the destination", async () => {
    const fixture = await makeFixture({
      dot_configfile: "worktree\n",
      "dot_newdir/config": "created\n",
    });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");

    await apply(fixture, { question: async () => "n", yes: false });

    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(path.join(fixture.home, ".newdir"));
    await expectAbsent(fixture.activeDir);
  });

  realTest("captures matching targets so application edits can still be reverted", async () => {
    const fixture = await makeFixture({ dot_configfile: "baseline\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");

    await apply(fixture);
    await fs.writeFile(target, "application edit\n");
    await revert(fixture);

    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(fixture.activeDir);
  });

  realTest("leaves an empty source without an active session", async () => {
    const fixture = await makeFixture({});
    await apply(fixture);

    expect(await fs.readdir(fixture.home)).toEqual([]);
    await expectAbsent(fixture.activeDir);
  });

  realTest("cleans newly created state directories when nothing is managed", async () => {
    const fixture = await makeFixture({});
    const sessionBase = path.join(fixture.home, ".local/state/chezmoi-worktree-test");
    await runLiveApply({
      destinationDir: fixture.home, question: async () => "y", sessionBase,
      worktreeRoot: fixture.worktree, yes: true,
    });

    expect(await fs.readdir(fixture.home)).toEqual([]);
  });

  realTest("rejects recovery storage that would change a missing managed ancestor", async () => {
    const fixture = await makeFixture({ "dot_local/bin/tool": "worktree\n" });
    const sessionBase = path.join(fixture.home, ".local/state/chezmoi-worktree-test");

    await expect(runLiveApply({
      destinationDir: fixture.home, question: async () => "y", sessionBase,
      worktreeRoot: fixture.worktree, yes: true,
    })).rejects.toThrow("recovery storage created a managed target");

    expect(await fs.readdir(fixture.home)).toEqual([]);
  });

  realTest("preserves edits made while apply confirmation is open", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");

    await expect(apply(fixture, {
      yes: false,
      question: async () => {
        await fs.writeFile(target, "concurrent edit\n");
        return "y";
      },
    })).rejects.toThrow("baseline changed before apply");

    expect(await fs.readFile(target, "utf8")).toBe("concurrent edit\n");
    await expectAbsent(fixture.activeDir);
  });

  realTest("retains the snapshot after cancelling revert or failing verification", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    const session = await openActiveSession(fixture.sessionBase, fixture.worktree, fixture.home);

    await expect(revertActiveSession({
      automatic: false, confirm: async () => false, session,
    })).rejects.toThrow("revert cancelled");
    expect(await fs.readFile(target, "utf8")).toBe("worktree\n");
    await expect(revertActiveSession({
      automatic: false,
      confirm: async () => true,
      session,
      runner: (command, args) => {
        const result = runCommand(command, args);
        return args.includes("verify") ? { ...result, status: 1 } : result;
      },
    })).rejects.toThrow("verify restored snapshot");

    expect((await fs.stat(fixture.activeDir)).isDirectory()).toBeTrue();
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(fixture.activeDir);
  });
});

type Tree = Record<string, string | Buffer | null>;
type Fixture = Awaited<ReturnType<typeof makeFixture>>;

async function makeFixture(sourceFiles: Tree) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-live-test-"));
  roots.push(root);
  const home = path.join(root, "fake-home");
  const worktree = path.join(root, "worktree");
  const source = path.join(worktree, "home");
  const sessionBase = path.join(root, "state");
  await fs.mkdir(home);
  await writeTree(source, {
    ".shared-configs/nvim": null,
    ".shared-configs/yazi": null,
    ".chezmoiignore": ".shared-configs\n",
    ...sourceFiles,
  });
  const git = Bun.spawnSync(["git", "init", "--quiet", worktree]);
  if (git.exitCode !== 0) throw new Error(git.stderr.toString());
  return { root, home, worktree, source, sessionBase, activeDir: path.join(sessionBase, "active") };
}

async function writeTree(root: string, files: Tree): Promise<void> {
  for (const [relative, contents] of Object.entries(files)) {
    const target = path.join(root, relative);
    await fs.mkdir(contents === null ? target : path.dirname(target), { recursive: true });
    if (contents !== null) await fs.writeFile(target, contents);
  }
}

async function apply(
  fixture: Fixture,
  options: Partial<Pick<Parameters<typeof runLiveApply>[0], "runner" | "question" | "yes">> = {},
): Promise<void> {
  await runLiveApply({
    destinationDir: fixture.home,
    question: async () => "y",
    sessionBase: fixture.sessionBase,
    worktreeRoot: fixture.worktree,
    yes: true,
    ...options,
  });
}

async function revert(fixture: Fixture): Promise<void> {
  const session = await openActiveSession(fixture.sessionBase, fixture.worktree, fixture.home);
  await revertActiveSession({ automatic: false, confirm: async () => true, session });
}

async function expectAbsent(target: string): Promise<void> {
  await expect(fs.lstat(target)).rejects.toMatchObject({ code: "ENOENT" });
}

function failAfterApply(fixture: Fixture, failRecovery = false): CommandRunner {
  let failed = false;
  return (command, args) => {
    const applying = command === "chezmoi" && args.includes("apply");
    if (applying && failRecovery && args.includes(path.join(fixture.activeDir, "snapshot-source"))) {
      return {
        signal: null,
        status: 1,
        stderr: Buffer.from("injected recovery failure\n"),
        stdout: Buffer.alloc(0),
      };
    }
    const result = runCommand(command, args);
    if (
      applying && !failed && result.status === 0 &&
      args.includes(path.join(fixture.activeDir, "staged-source"))
    ) {
      failed = true;
      return { ...result, status: 1, stderr: Buffer.from("injected apply failure\n") };
    }
    return result;
  };
}
