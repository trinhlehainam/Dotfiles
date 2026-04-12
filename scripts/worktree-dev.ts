import { spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";

const commands = ["context", "diff", "dry-run", "apply-temp"] as const;
const usage = `usage: bun run scripts/worktree-dev.ts [--help] <${commands.join("|")}>`;

export type WorktreeCommand = (typeof commands)[number];
export type ParsedCliArgs = {
  command?: WorktreeCommand;
  help: boolean;
};

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function writeUsage(): void {
  process.stdout.write(`${usage}\n`);
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

const commandArgs: Record<WorktreeCommand, (worktree: string) => string[]> = {
  context: (worktree) => [
    "execute-template",
    ...commonArgs(worktree),
    "{{ .chezmoi.workingTree }}|{{ .chezmoi.sourceDir }}",
  ],
  diff: (worktree) => ["diff", ...commonArgs(worktree)],
  "dry-run": (worktree) => ["apply", ...commonArgs(worktree), "-n", "-v"],
  "apply-temp": (worktree) => {
    const destDir = mkdtempSync(path.join(os.tmpdir(), "chezmoi-worktree-"));
    process.stderr.write(`temporary destination: ${destDir}\n`);
    return ["apply", ...commonArgs(worktree), "-v", "-D", destDir];
  },
};

function parseCommand(value: string | undefined): WorktreeCommand | undefined {
  if (value === undefined) {
    return undefined;
  }

  if (Object.hasOwn(commandArgs, value)) {
    return value as WorktreeCommand;
  }

  fail(`unknown command: ${value}\n${usage}`);
}

export function parseCliArgs(args: string[]): ParsedCliArgs {
  let values: { help?: boolean };
  let positionals: string[];

  try {
    ({ values, positionals } = parseArgs({
      args,
      options: {
        help: { type: "boolean", short: "h", default: false },
      },
      allowPositionals: true,
    }));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    fail(`${message}\n${usage}`);
  }

  if (positionals.length > 1) {
    fail(`expected exactly one command\n${usage}`);
  }

  return {
    command: parseCommand(positionals[0]),
    help: values.help === true,
  };
}

function main(): void {
  const parsed = parseCliArgs(process.argv.slice(2));
  if (parsed.help) {
    writeUsage();
    process.exit(0);
  }

  if (parsed.command === undefined) {
    fail(usage);
  }

  const worktree = resolveWorktreeRoot();
  const result = spawnSync("chezmoi", commandArgs[parsed.command](worktree), {
    cwd: process.cwd(),
    stdio: "inherit",
  });

  if (result.error) {
    fail(`failed to run chezmoi: ${result.error.message}`);
  }

  process.exit(result.status ?? 1);
}

if (import.meta.main) {
  main();
}
