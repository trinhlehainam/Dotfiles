import { spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import os from "node:os";
import path from "node:path";

const commands = ["context", "diff", "dry-run", "apply-temp"] as const;

type WorktreeCommand = (typeof commands)[number];

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function resolveWorktreeRoot(): string {
  const result = spawnSync("git", ["rev-parse", "--show-toplevel"], {
    cwd: process.cwd(),
    encoding: "utf8",
  });

  if (result.error) {
    fail(`failed to run git: ${result.error.message}`);
  }

  if (result.status !== 0) {
    fail(result.stderr.trim() || "failed to resolve git worktree root");
  }

  const worktree = result.stdout.trim();
  if (!worktree) {
    fail("git returned an empty worktree root");
  }

  return worktree;
}

function commonArgs(worktree: string): string[] {
  return ["--init", "-S", path.join(worktree, "home"), "-W", worktree];
}

function chezmoiCommandArgs(command: WorktreeCommand, worktree: string): string[] {
  const baseArgs = commonArgs(worktree);

  switch (command) {
    case "context":
      return [
        "execute-template",
        ...baseArgs,
        "{{ .chezmoi.workingTree }}|{{ .chezmoi.sourceDir }}",
      ];
    case "diff":
      return ["diff", ...baseArgs];
    case "dry-run":
      return ["apply", ...baseArgs, "-n", "-v"];
    case "apply-temp": {
      const destDir = mkdtempSync(path.join(os.tmpdir(), "chezmoi-worktree-"));
      process.stderr.write(`temporary destination: ${destDir}\n`);
      return ["apply", ...baseArgs, "-v", "-D", destDir];
    }
  }
}

function parseCommand(value: string | undefined): WorktreeCommand {
  if (value === undefined) {
    fail(`usage: bun run scripts/worktree-dev.ts <${commands.join("|")}>`);
  }

  if ((commands as readonly string[]).includes(value)) {
    return value as WorktreeCommand;
  }

  fail(`unknown command: ${value}`);
}

function main(): void {
  const command = parseCommand(process.argv[2]);
  const worktree = resolveWorktreeRoot();
  const result = spawnSync("chezmoi", chezmoiCommandArgs(command, worktree), {
    cwd: process.cwd(),
    stdio: "inherit",
  });

  if (result.error) {
    fail(`failed to run chezmoi: ${result.error.message}`);
  }

  process.exit(result.status ?? 1);
}

main();
