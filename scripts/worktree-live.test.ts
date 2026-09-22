import { afterEach, describe, expect, test } from "bun:test";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import { runWorktreeCommand } from "./worktree-dev.ts";
import { runCoordinatedChezmoi } from "./chezmoi.ts";
import { runCommand, type CommandRunner } from "./worktree-runtime.ts";
import {
  createActiveSession,
  openActiveSession,
  revertActiveSession,
  runLiveApply,
  applyMainWithWorktree,
  resolveSessionBase,
} from "./worktree-session.ts";

const realTest = Bun.which("chezmoi") && Bun.which("git") ? test : test.skip;
const posixTest = process.platform === "win32" ? test.skip : realTest;
const roots: string[] = [];

afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("worktree apply and revert with real chezmoi", () => {
  realTest("main apply keeps the worktree active and replaces its revert baseline", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n", dot_only_worktree: "temporary\n" });
    await writeTree(fixture.home, { ".configfile": "local edits\n" });
    await apply(fixture);
    const main = path.join(fixture.root, "main");
    await writeTree(main, { dot_configfile: "main\n", dot_only_main: "keep\n" });

    await applyMainWithWorktree({
      destinationDir: fixture.home,
      sessionBase: fixture.sessionBase,
      apply: () => runCommand("chezmoi", mainApplyArgs(fixture, main)),
    });

    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("worktree\n");
    expect(await fs.readFile(path.join(fixture.home, ".only_worktree"), "utf8")).toBe("temporary\n");
    await revert(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("main\n");
    expect(await fs.readFile(path.join(fixture.home, ".only_main"), "utf8")).toBe("keep\n");
    await expectAbsent(path.join(fixture.home, ".only_worktree"));
  });

  realTest("partial main failure keeps its result as the baseline and returns the failure", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    await writeTree(fixture.home, { ".configfile": "old\n" });
    await apply(fixture);
    const result = await applyMainWithWorktree({
      destinationDir: fixture.home,
      sessionBase: fixture.sessionBase,
      apply: async () => {
        await fs.writeFile(path.join(fixture.home, ".configfile"), "partial main\n");
        return { status: 1, signal: null, stdout: Buffer.alloc(0), stderr: Buffer.from("failed") };
      },
    });
    expect(result.status).toBe(1);
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("worktree\n");
    await revert(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("partial main\n");
  });

  realTest("normal CLI dry run leaves test edits intact, then targeted apply updates only its baseline", async () => {
    const fixture = await makeFixture({ "dot_with space": "worktree\n", dot_other: "worktree\n" });
    await writeTree(fixture.home, { ".with space": "old\n", ".other": "old\n" });
    await apply(fixture);
    const main = path.join(fixture.root, "main source");
    await writeTree(main, { "dot_with space": "main\n", dot_other: "main\n" });
    const before = await readSnapshot(fixture);
    await fs.writeFile(path.join(fixture.home, ".other"), "test edits\n");
    const options = { homeDir: fixture.home, sessionBase: fixture.sessionBase };

    expect((await runCoordinatedChezmoi([...mainApplyArgs(fixture, main), "-n"], options)).status).toBe(0);
    expect(await readSnapshot(fixture)).toEqual(before);
    expect(await fs.readFile(path.join(fixture.home, ".other"), "utf8")).toBe("test edits\n");
    expect((await runCoordinatedChezmoi([
      ...mainApplyArgs(fixture, main), "--", path.join(fixture.home, ".with space"),
    ], options)).status).toBe(0);
    expect(await fs.readFile(path.join(fixture.home, ".with space"), "utf8")).toBe("worktree\n");
    await revert(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".with space"), "utf8")).toBe("main\n");
    expect(await fs.readFile(path.join(fixture.home, ".other"), "utf8")).toBe("old\n");
  });

  realTest("main exact directories see the restored baseline before computing removals", async () => {
    const fixture = await makeFixture({ "dot_dir/worktree": "temporary\n" });
    await writeTree(fixture.home, { ".dir/unmanaged": "old\n" });
    await apply(fixture);
    const main = path.join(fixture.root, "main");
    await writeTree(main, { "exact_dot_dir/main": "main\n" });
    await runCoordinatedChezmoi(mainApplyArgs(fixture, main), {
      homeDir: fixture.home, sessionBase: fixture.sessionBase,
    });
    await expectAbsent(path.join(fixture.home, ".dir/unmanaged"));
    await revert(fixture);
    expect(await fs.readdir(path.join(fixture.home, ".dir"))).toEqual(["main"]);
  });

  realTest("failed worktree resume cannot leave an old snapshot that undoes main", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    await writeTree(fixture.home, { ".configfile": "old\n" });
    await apply(fixture);
    await writeTree(fixture.source, { run_before_unsupported: "exit 0\n" });
    await expect(applyMainWithWorktree({
      destinationDir: fixture.home,
      sessionBase: fixture.sessionBase,
      apply: async () => {
        await fs.writeFile(path.join(fixture.home, ".configfile"), "new main\n");
        return { status: 0, signal: null, stdout: Buffer.alloc(0), stderr: Buffer.alloc(0) };
      },
    })).rejects.toThrow("Could not resume worktree");
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("new main\n");
    await expectAbsent(fixture.activeDir);
    await expectAbsent(path.join(fixture.sessionBase, "operation"));
  });

  for (const shell of ["bash", "pwsh"] as const) {
    (Bun.which(shell) ? realTest : test.skip)(`${shell} function coordinates apply and the native hook prevents bypass`, async () => {
      const fixture = await makeFixture({ "dot_with space": "worktree\n" });
      const env = { ...process.env, HOME: fixture.home, USERPROFILE: fixture.home,
        XDG_STATE_HOME: path.join(fixture.root, "state"), LOCALAPPDATA: path.join(fixture.home, "AppData/Local") };
      fixture.sessionBase = resolveSessionBase(process.platform, fixture.home, env);
      fixture.activeDir = path.join(fixture.sessionBase, "active");
      await writeTree(fixture.home, { ".with space": "old\n" });
      await apply(fixture);
      const main = path.join(fixture.root, "main source");
      await writeTree(main, { "dot_with space": "main\n" });
      const args = mainApplyArgs(fixture, main);
      const repo = path.dirname(import.meta.dir);
      const templateFile = shell === "bash" ? "home/dot_bash_aliases.tmpl"
        : "home/.chezmoitemplates/PowerShell/Microsoft.PowerShell_profile.ps1";
      const template = await fs.readFile(path.join(repo, templateFile), "utf8");
      const functionTemplate = template.match(/(?:function chezmoi|chezmoi\(\)) \{[\s\S]*?\n\}/)![0];
      const rendered = runCommand("chezmoi", [...args.slice(0, -2), "--working-tree", repo,
        "execute-template", functionTemplate]);
      expect(rendered.status).toBe(0);
      await fs.writeFile(path.join(fixture.root, "empty.toml"), `[hooks.apply.pre]\ncommand = "bun"\nargs = ${JSON.stringify(["run", path.join(repo, "scripts/chezmoi.ts"), "--guard"])}\n`);
      const bypass = Bun.spawnSync(["chezmoi", ...args], { env });
      expect(bypass.exitCode).not.toBe(0);
      expect(bypass.stderr.toString()).toContain("coordinated chezmoi apply");
      expect(await fs.readFile(path.join(fixture.home, ".with space"), "utf8")).toBe("worktree\n");
      const launcher = path.join(fixture.root, shell === "bash" ? "apply.sh" : "apply.ps1");
      await fs.writeFile(launcher, rendered.stdout.toString() + (shell === "bash"
        ? '\nchezmoi "$@"\n'
        : '\n$nativeArgs = ConvertFrom-Json $env:TEST_CHEZMOI_ARGS\nif ($env:TEST_PIPE_INPUT) { $env:TEST_PIPE_INPUT | chezmoi @nativeArgs } else { chezmoi @nativeArgs }\nexit $LASTEXITCODE\n'));
      const run = (nativeArgs: string[], input = "") => Bun.spawnSync(shell === "bash"
        ? [shell, "--noprofile", "--norc", launcher, ...nativeArgs]
        : [shell, "-NoProfile", "-File", launcher], {
        env: { ...env, TEST_CHEZMOI_ARGS: JSON.stringify(nativeArgs), TEST_PIPE_INPUT: input },
        stdin: shell === "bash" ? Buffer.from(input) : "ignore",
      });
      const piped = run([...args.slice(0, -2), "execute-template"], '{{ "pipeline preserved" }}');
      expect(piped.exitCode).toBe(0);
      expect(piped.stdout.toString().trim()).toBe("pipeline preserved");
      const snapshot = await readSnapshot(fixture);
      const dryRun = run([...args, "-n"]);
      expect(dryRun.stderr.toString()).toBe("");
      expect(dryRun.exitCode).toBe(0);
      expect(await readSnapshot(fixture)).toEqual(snapshot);
      const applied = run([...args, path.join(fixture.home, ".with space")]);
      if (applied.exitCode !== 0) throw new Error(applied.stderr.toString());
      expect(await fs.readFile(path.join(fixture.home, ".with space"), "utf8")).toBe("worktree\n");
      await revert(fixture);
      expect(await fs.readFile(path.join(fixture.home, ".with space"), "utf8")).toBe("main\n");
    });
  }

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

  realTest("applies and reverts a bare-repository worktree without exposing Git metadata", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const bare = path.join(fixture.home, ".dotfiles repo");
    const seed = path.join(fixture.root, "seed");
    const git = (...args: string[]) => {
      const result = Bun.spawnSync(["git", ...args]);
      if (result.exitCode !== 0) throw new Error(result.stderr.toString());
    };
    git("-C", fixture.worktree, "add", ".");
    git("-C", fixture.worktree, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
      "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "fixture");
    await fs.rename(fixture.worktree, seed);
    git("clone", "--quiet", "--bare", seed, bare);
    git("--git-dir", bare, "worktree", "add", "--quiet", "-b", "probe", fixture.worktree);
    await writeTree(fixture.source, { ".shared-configs/nvim": null, ".shared-configs/yazi": null });
    const config = await fs.readFile(path.join(bare, "config"));
    await writeTree(fixture.home, { ".configfile": "baseline\n" });

    await apply(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("worktree\n");
    await revert(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("baseline\n");

    await writeTree(fixture.source, { "dot_dotfiles repo/config": "must not apply\n" });
    await expect(apply(fixture)).rejects.toThrow("managed target is inside normal source directory");
    expect(await fs.readFile(path.join(bare, "config"))).toEqual(config);
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

    await expect(revert(fixture)).rejects.toThrow("cannot revert directory containing uncaptured path");

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

    await expect(revert(fixture)).rejects.toThrow("unsupported directory type change");

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

  realTest("reapplies the owner worktree and restores dropped targets without recapturing baseline", async () => {
    const fixture = await makeFixture({
      dot_configfile: "first worktree\n",
      dot_dropped: "first worktree\n",
      dot_created: "created\n",
      "dot_newdir/nested/config": "created\n",
    });
    const target = path.join(fixture.home, ".configfile");
    await writeTree(fixture.home, {
      ".configfile": "baseline\n",
      ".dropped": "dropped baseline\n",
    });
    await apply(fixture);
    const snapshot = await readSnapshot(fixture);
    await fs.writeFile(path.join(fixture.source, "dot_configfile"), "second worktree\n");
    for (const dropped of ["dot_dropped", "dot_created", "dot_newdir"]) {
      await fs.rm(path.join(fixture.source, dropped), { recursive: true });
    }

    await apply(fixture);

    expect(await fs.readFile(target, "utf8")).toBe("second worktree\n");
    expect(await fs.readFile(path.join(fixture.home, ".dropped"), "utf8"))
      .toBe("dropped baseline\n");
    await expectAbsent(path.join(fixture.home, ".created"));
    await expectAbsent(path.join(fixture.home, ".newdir"));
    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(fixture.activeDir);
  });

  realTest("preserves the original baseline across separate apply and revert processes", async () => {
    const fixture = await makeFixture({ dot_configfile: "first\n" });
    await fs.writeFile(path.join(fixture.home, ".configfile"), "baseline\n");

    await runLiveProcess(fixture, "apply");
    const snapshot = await readSnapshot(fixture);
    await fs.writeFile(path.join(fixture.source, "dot_configfile"), "second\n");
    await runLiveProcess(fixture, "apply");
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("second\n");
    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await runLiveProcess(fixture, "revert");
    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("baseline\n");
    await expectAbsent(fixture.activeDir);
    await expectAbsent(path.join(fixture.sessionBase, "operation"));
  });

  realTest.each(["new", "preexisting", "nonempty"])(
    "prunes only created empty state directories across processes (%s parent)",
    async (parentState) => {
      const fixture = await makeFixture({ dot_created: "worktree\n" });
      const parent = path.join(fixture.home, ".local");
      fixture.sessionBase = path.join(parent, "state", "chezmoi-worktree-test");
      fixture.activeDir = path.join(fixture.sessionBase, "active");
      if (parentState === "preexisting") await fs.mkdir(parent);

      await runLiveProcess(fixture, "apply");
      if (parentState === "nonempty") await fs.writeFile(path.join(parent, "keep"), "keep\n");
      await runLiveProcess(fixture, "revert");

      await expectAbsent(path.join(fixture.home, ".created"));
      await expectAbsent(path.join(parent, "state"));
      if (parentState === "new") {
        await expectAbsent(parent);
      } else {
        expect(await fs.readdir(parent)).toEqual(parentState === "nonempty" ? ["keep"] : []);
        if (parentState === "nonempty") {
          expect(await fs.readFile(path.join(parent, "keep"), "utf8")).toBe("keep\n");
        }
      }
    },
  );

  realTest("allows an empty repeat and later reintroduction of an originally captured target", async () => {
    const fixture = await makeFixture({ dot_created: "first\n" });
    await apply(fixture);
    const snapshot = await readSnapshot(fixture);
    await fs.unlink(path.join(fixture.source, "dot_created"));
    await apply(fixture);
    await expectAbsent(path.join(fixture.home, ".created"));
    await fs.writeFile(path.join(fixture.source, "dot_created"), "reintroduced\n");
    await apply(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".created"), "utf8")).toBe("reintroduced\n");
    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await revert(fixture);
    await expectAbsent(path.join(fixture.home, ".created"));
  });

  realTest("rejects managed targets inside the operation lock directory", async () => {
    const fixture = await makeFixture({ "dot_state/operation/file": "must not apply\n" });
    const sessionBase = path.join(fixture.home, ".state");
    await fs.mkdir(sessionBase);
    await expect(runLiveApply({
      destinationDir: fixture.home, question: async () => "y", sessionBase,
      worktreeRoot: fixture.worktree, yes: true,
    })).rejects.toThrow("managed target is inside session directory");
    expect(await fs.readdir(sessionBase)).toEqual([]);
  });

  realTest("rejects new repeat-apply targets before changing HOME or the original snapshot", async () => {
    const fixture = await makeFixture({ dot_configfile: "first worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await writeTree(fixture.home, {
      ".configfile": "baseline\n",
      ".extra": "uncaptured baseline\n",
    });
    await apply(fixture);
    const snapshot = await readSnapshot(fixture);
    await writeTree(fixture.source, {
      dot_configfile: "second worktree\n",
      dot_extra: "must not apply\n",
    });

    await expect(apply(fixture)).rejects.toThrow(/uncaptured|new target/);

    expect(await fs.readFile(target, "utf8")).toBe("first worktree\n");
    expect(await fs.readFile(path.join(fixture.home, ".extra"), "utf8"))
      .toBe("uncaptured baseline\n");
    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    expect(await fs.readFile(path.join(fixture.home, ".extra"), "utf8"))
      .toBe("uncaptured baseline\n");
  });

  realTest("keeps the tested HOME and original snapshot when repeat apply is cancelled or invalid", async () => {
    const fixture = await makeFixture({ dot_configfile: "first worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    const snapshot = await readSnapshot(fixture);
    await fs.writeFile(path.join(fixture.source, "dot_configfile"), "second worktree\n");

    await apply(fixture, { question: async () => "n", yes: false });

    expect(await fs.readFile(target, "utf8")).toBe("first worktree\n");
    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await fs.writeFile(path.join(fixture.source, "run_bad.sh"), "exit 1\n");
    await expect(apply(fixture)).rejects.toThrow(/unsupported/);
    expect(await fs.readFile(target, "utf8")).toBe("first worktree\n");
    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
  });

  realTest("reserves the session before starting apply", async () => {
    const fixture = await makeFixture({ dot_created: "worktree\n" });
    await createActiveSession(fixture.sessionBase, fixture.worktree, fixture.home);

    await expect(apply(fixture)).rejects.toThrow("Incomplete session");

    await expectAbsent(path.join(fixture.home, ".created"));
    expect((await fs.stat(fixture.activeDir)).isDirectory()).toBeTrue();
  });

  realTest("rejects recovery from a different destination and preserves the snapshot", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    const other = await makeFixture({ dot_configfile: "other worktree\n" });
    const otherTarget = path.join(other.home, ".configfile");
    await fs.writeFile(otherTarget, "other baseline\n");

    await expect(openActiveSession(
      fixture.sessionBase,
      fixture.worktree,
      other.home,
    )).rejects.toThrow(/destination/);

    expect(await fs.readFile(target, "utf8")).toBe("worktree\n");
    expect(await fs.readFile(otherTarget, "utf8")).toBe("other baseline\n");
    expect((await fs.stat(fixture.activeDir)).isDirectory()).toBeTrue();
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    expect(await fs.readFile(otherTarget, "utf8")).toBe("other baseline\n");
    await expectAbsent(fixture.activeDir);
  });

  realTest("blocks another worktree's apply but permits it to revert the owner's snapshot", async () => {
    const fixture = await makeFixture({ dot_configfile: "owner worktree\n" });
    const other = await makeFixture({ dot_configfile: "other worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    const snapshot = await readSnapshot(fixture);

    await expect(runLiveApply({
      destinationDir: fixture.home,
      question: async () => "y",
      sessionBase: fixture.sessionBase,
      worktreeRoot: other.worktree,
      yes: true,
    })).rejects.toThrow(fixture.worktree);

    expect(await fs.readFile(target, "utf8")).toBe("owner worktree\n");
    expect(await readSnapshot(fixture)).toEqual(snapshot);
    const session = await openActiveSession(fixture.sessionBase, other.worktree, fixture.home);
    expect(session.worktreeRoot).toBe(fixture.worktree);
    await revertActiveSession({ confirm: async () => true, session });
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(fixture.activeDir);
  });

  realTest("serializes apply and revert while repeat-apply confirmation is open", async () => {
    const fixture = await makeFixture({ dot_configfile: "first worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    const snapshot = await readSnapshot(fixture);
    await fs.writeFile(path.join(fixture.source, "dot_configfile"), "second worktree\n");

    await apply(fixture, {
      yes: false,
      question: async () => {
        await expect(apply(fixture)).rejects.toThrow("worktree operation already in progress");
        await expect(revert(fixture)).rejects.toThrow("worktree operation already in progress");
        expect(await fs.readFile(target, "utf8")).toBe("first worktree\n");
        expect(await readSnapshot(fixture)).toEqual(snapshot);
        return "n";
      },
    });

    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
  });

  realTest("serializes apply and revert while revert confirmation is open", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    const snapshot = await readSnapshot(fixture);
    const session = await openActiveSession(fixture.sessionBase, fixture.worktree, fixture.home);

    await expect(revertActiveSession({
      session,
      confirm: async () => {
        await expect(apply(fixture)).rejects.toThrow("worktree operation already in progress");
        await expect(revert(fixture)).rejects.toThrow("worktree operation already in progress");
        expect(await fs.readFile(target, "utf8")).toBe("worktree\n");
        expect(await readSnapshot(fixture)).toEqual(snapshot);
        return false;
      },
    })).rejects.toThrow("revert cancelled");

    expect(await readSnapshot(fixture)).toEqual(snapshot);
    await revert(fixture);
    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
  });

  realTest("reconciles removal entries against the apply-temp destination", async () => {
    const fixture = await makeFixture({});
    const staleEntry = `.config/nvim/${path.basename(fixture.root)}-stale.lua`;
    await writeTree(fixture.home, { [staleEntry]: "stale config\n" });
    await fs.writeFile(path.join(fixture.source, ".chezmoiremove"), `${staleEntry}\n`);

    const result = await runWorktreeCommand("apply-temp", fixture.worktree, fixture.home);

    expect(result.status).toBe(0);
    await expectAbsent(path.join(fixture.home, staleEntry));
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

  realTest("restores the original baseline when a repeated apply fails", async () => {
    const fixture = await makeFixture({
      dot_configfile: "first worktree\n",
      "dot_newdir/config": "first worktree\n",
    });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");
    await apply(fixture);
    await writeTree(fixture.source, {
      dot_configfile: "second worktree\n",
      "dot_newdir/config": "second worktree\n",
    });

    await expect(apply(fixture, { runner: failAfterApply(fixture) }))
      .rejects.toThrow("injected apply failure");

    expect(await fs.readFile(target, "utf8")).toBe("baseline\n");
    await expectAbsent(path.join(fixture.home, ".newdir"));
    await expectAbsent(fixture.activeDir);
    await expectAbsent(fixture.sessionBase);
  });

  realTest("keeps the snapshot when automatic recovery fails and allows manual retry", async () => {
    const fixture = await makeFixture({ dot_configfile: "worktree\n" });
    const target = path.join(fixture.home, ".configfile");
    await fs.writeFile(target, "baseline\n");

    await expect(apply(fixture, { runner: failAfterApply(fixture, true) }))
      .rejects.toThrow(/apply and automatic revert failed[\s\S]*injected apply failure[\s\S]*injected recovery failure/);

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

  realTest("rejects create-encrypted targets before changing HOME", async () => {
    const fixture = await makeFixture({
      dot_configfile: "worktree\n",
      create_encrypted_dot_secret: "encrypted contents\n",
    });
    await fs.writeFile(path.join(fixture.home, ".configfile"), "baseline\n");

    await expect(apply(fixture)).rejects.toThrow("unsupported source attribute: create_encrypted_dot_secret");

    expect(await fs.readFile(path.join(fixture.home, ".configfile"), "utf8")).toBe("baseline\n");
    await expectAbsent(path.join(fixture.home, ".secret"));
    await expectAbsent(fixture.activeDir);
  });

  realTest("supports create files and external directories through apply and revert", async () => {
    const fixture = await makeFixture({
      create_dot_existing: "worktree\n",
      create_dot_created: "created\n",
      "external_bundle/dot_literal": "external contents\n",
    });
    await fs.writeFile(path.join(fixture.home, ".existing"), "baseline\n");

    await apply(fixture);

    expect(await fs.readFile(path.join(fixture.home, ".existing"), "utf8")).toBe("baseline\n");
    expect(await fs.readFile(path.join(fixture.home, ".created"), "utf8")).toBe("created\n");
    expect(await fs.readFile(path.join(fixture.home, "bundle/dot_literal"), "utf8"))
      .toBe("external contents\n");
    await revert(fixture);
    expect(await fs.readFile(path.join(fixture.home, ".existing"), "utf8")).toBe("baseline\n");
    await expectAbsent(path.join(fixture.home, ".created"));
    await expectAbsent(path.join(fixture.home, "bundle"));
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
      confirm: async () => false, session,
    })).rejects.toThrow("revert cancelled");
    expect(await fs.readFile(target, "utf8")).toBe("worktree\n");
    await expect(revertActiveSession({
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

function mainApplyArgs(fixture: Fixture, source: string): string[] {
  return ["--source", source, "--destination", fixture.home,
    "--config", path.join(fixture.root, "empty.toml"),
    "--cache", path.join(fixture.root, "main-cache"),
    "--persistent-state", path.join(fixture.root, "main-state.boltdb"), "--force", "apply"];
}

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

async function readSnapshot(fixture: Fixture): Promise<Record<string, string | null>> {
  const root = path.join(fixture.activeDir, "snapshot-source");
  const contents: Record<string, string | null> = {};
  for (const relative of await fs.readdir(root, { recursive: true })) {
    const target = path.join(root, relative);
    contents[relative] = (await fs.lstat(target)).isDirectory()
      ? null
      : (await fs.readFile(target)).toString("base64");
  }
  return contents;
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
  await revertActiveSession({ confirm: async () => true, session });
}

async function runLiveProcess(fixture: Fixture, command: "apply" | "revert"): Promise<void> {
  const options = {
    destinationDir: fixture.home, sessionBase: fixture.sessionBase,
    worktreeRoot: fixture.worktree, yes: true,
  };
  const script = `
    import { runLiveCliCommand } from ${JSON.stringify(import.meta.path.replace("worktree-live.test.ts", "worktree-dev.ts"))};
    await runLiveCliCommand(${JSON.stringify(command)}, {
      ...${JSON.stringify(options)}, question: async () => "y",
    });
  `;
  const child = Bun.spawn([process.execPath, "-e", script], { stdout: "ignore", stderr: "pipe" });
  const [stderr, exitCode] = await Promise.all([new Response(child.stderr).text(), child.exited]);
  if (exitCode !== 0) throw new Error(stderr);
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
