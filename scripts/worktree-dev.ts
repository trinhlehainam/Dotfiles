import { spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { createInterface } from "node:readline/promises";
import { parseArgs } from "node:util";

import { resolveSourceStateRoot } from "./chezmoi-paths.ts";
import { reconcileAllTools } from "./reconcile-configs.ts";
import {
  createEphemeralRuntime,
  removeEphemeralRuntime,
  runChezmoi,
  streamCommand,
  type CommandResult,
} from "./worktree-runtime.ts";
import {
  openActiveSession,
  resolveSessionBase,
  revertActiveSession,
  runLiveApply,
  type Question,
} from "./worktree-session.ts";

const commands = ["context", "diff", "dry-run", "apply-temp", "apply", "revert"] as const;
const usage = `usage: bun run scripts/worktree-dev.ts [--help|-h] [--yes] <${commands.join("|")}>`;

export type NonLiveCommand = "context" | "diff" | "dry-run" | "apply-temp";
export type LiveCommand = "apply" | "revert";
export type WorktreeCommand = NonLiveCommand | LiveCommand;
export type ParsedCliArgs = {
  command?: WorktreeCommand;
  help: boolean;
  yes: boolean;
};

export function buildNonLiveCommandArgs(command: NonLiveCommand): string[] {
  switch (command) {
    case "context":
      return ["execute-template", "{{ .chezmoi.workingTree }}|{{ .chezmoi.sourceDir }}"];
    case "diff":
      return ["diff"];
    case "dry-run":
      return ["apply", "--dry-run", "--verbose"];
    case "apply-temp":
      return ["apply", "--verbose"];
  }
}

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

type WorktreeCommandDependencies = {
  reconcile: typeof reconcileAllTools;
  createRuntime: typeof createEphemeralRuntime;
  run: typeof runChezmoi;
  removeRuntime: typeof removeEphemeralRuntime;
};

const defaultWorktreeCommandDependencies: WorktreeCommandDependencies = {
  reconcile: reconcileAllTools,
  createRuntime: createEphemeralRuntime,
  run: (runtime, args) => runChezmoi(runtime, args, streamCommand),
  removeRuntime: removeEphemeralRuntime,
};

type LiveCliOptions = {
  destinationDir: string;
  question: Question;
  sessionBase: string;
  worktreeRoot: string;
  yes: boolean;
};

type LiveCliDependencies = {
  apply: typeof runLiveApply;
  openSession: typeof openActiveSession;
  revert: typeof revertActiveSession;
};

const defaultLiveCliDependencies: LiveCliDependencies = {
  apply: runLiveApply,
  openSession: openActiveSession,
  revert: revertActiveSession,
};

export async function runLiveCliCommand(
  command: LiveCommand,
  options: LiveCliOptions,
  dependencies: LiveCliDependencies = defaultLiveCliDependencies,
): Promise<void> {
  if (command === "apply") {
    await dependencies.apply(options);
    return;
  }

  const session = await dependencies.openSession(
    options.sessionBase,
    options.worktreeRoot,
    options.destinationDir,
  );
  await dependencies.revert({
    confirm: async (lines) => {
      if (options.yes) return true;
      const answer = await options.question(
        `${lines.join("\n")}\nRevert these changes? [y/N] `,
      );
      return answer.trim().toLowerCase() === "y";
    },
    session,
  });
}

export async function runWorktreeCommand(
  command: NonLiveCommand,
  worktreeRoot: string,
  destinationDir: string,
  dependencies: WorktreeCommandDependencies = defaultWorktreeCommandDependencies,
): Promise<CommandResult> {
  const sourceDir = resolveSourceStateRoot(worktreeRoot);
  await dependencies.reconcile({
    hostHome: destinationDir,
    repoRoot: worktreeRoot,
    sourceStateRoot: sourceDir,
  });
  const runtime = await dependencies.createRuntime({
    destinationDir,
    sourceDir,
    worktreeRoot,
  });

  try {
    return dependencies.run(runtime, buildNonLiveCommandArgs(command));
  } finally {
    await dependencies.removeRuntime(runtime);
  }
}

function parseCommand(value: string | undefined): WorktreeCommand | undefined {
  if (value === undefined) {
    return undefined;
  }

  if (commands.includes(value as WorktreeCommand)) {
    return value as WorktreeCommand;
  }

  throw usageError(`unknown command: ${value}`);
}

export function parseCliArgs(args: string[]): ParsedCliArgs {
  let values: { help?: boolean; yes?: boolean };
  let positionals: string[];

  try {
    ({ values, positionals } = parseArgs({
      args,
      options: {
        help: { type: "boolean", short: "h", default: false },
        yes: { type: "boolean", default: false },
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

  const command = parseCommand(positionals[0]);
  const yes = values.yes === true;
  if (yes && command !== "apply" && command !== "revert") {
    throw usageError("--yes is only valid with apply or revert");
  }

  return {
    command,
    help: values.help === true,
    yes,
  };
}

async function askQuestion(prompt: string): Promise<string> {
  const readline = createInterface({ input: process.stdin, output: process.stdout });
  try {
    return await readline.question(prompt);
  } finally {
    readline.close();
  }
}

async function main(): Promise<void> {
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
  let destinationDir = os.homedir();

  if (parsed.command === "apply-temp") {
    try {
      destinationDir = mkdtempSync(path.join(os.tmpdir(), "chezmoi-worktree-"));
    } catch (error) {
      fail(error instanceof Error ? error.message : String(error));
    }

    process.stderr.write(`temporary destination: ${destinationDir}\n`);
  }

  if (parsed.command === "apply" || parsed.command === "revert") {
    try {
      await runLiveCliCommand(parsed.command, {
        destinationDir,
        question: askQuestion,
        sessionBase: resolveSessionBase(process.platform, destinationDir, process.env),
        worktreeRoot: worktree,
        yes: parsed.yes,
      });
    } catch (error) {
      fail(error instanceof Error ? error.message : String(error));
    }
    return;
  }

  const result = await runWorktreeCommand(parsed.command, worktree, destinationDir);
  handleSpawnResult(result);
}

if (import.meta.main) {
  await main();
}
