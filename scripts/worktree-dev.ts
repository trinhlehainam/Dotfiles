import { spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";

import { resolveSourceStateRoot } from "./chezmoi-paths.ts";

const commands = ["context", "diff", "dry-run", "apply-temp"] as const;
const usage = `usage: bun run scripts/worktree-dev.ts [--help|-h] <${commands.join("|")}>`;

export type WorktreeCommand = (typeof commands)[number];
export type ParsedCliArgs = {
  command?: WorktreeCommand;
  help: boolean;
};

export class ParseCliError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ParseCliError";
  }
}

type SpawnResult = {
  error?: Error;
  signal?: NodeJS.Signals | null;
  status?: number | null;
};

type SpawnResultHandlers = {
  fail: (message: string) => void;
  exit: (code: number) => void;
  raiseSignal: (signal: NodeJS.Signals) => void;
};

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function writeUsage(): void {
  process.stdout.write(`${usage}\n`);
}

function usageError(message: string): ParseCliError {
  return new ParseCliError(`${message}\n${usage}`);
}

export function handleSpawnResult(
  result: SpawnResult,
  handlers: SpawnResultHandlers = {
    fail,
    exit: (code) => process.exit(code),
    raiseSignal: (signal) => process.kill(process.pid, signal),
  },
): void {
  if (result.error) {
    handlers.fail(`failed to run chezmoi: ${result.error.message}`);
    return;
  }

  if (result.signal) {
    handlers.raiseSignal(result.signal);
    return;
  }

  handlers.exit(result.status ?? 1);
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
  return ["--init", "-S", resolveSourceStateRoot(worktree), "-W", worktree];
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

  throw usageError(`unknown command: ${value}`);
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
    throw usageError(message);
  }

  if (positionals.length > 1) {
    throw usageError("expected exactly one command");
  }

  return {
    command: parseCommand(positionals[0]),
    help: values.help === true,
  };
}

function main(): void {
  let parsed: ParsedCliArgs;

  try {
    parsed = parseCliArgs(process.argv.slice(2));
  } catch (error) {
    if (error instanceof ParseCliError) {
      fail(error.message);
    }

    throw error;
  }

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
  handleSpawnResult(result);
}

if (import.meta.main) {
  main();
}
