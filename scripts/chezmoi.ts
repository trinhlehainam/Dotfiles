import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";

import { requireSuccess, runCommand, type CommandResult } from "./worktree-runtime.ts";
import { applyMainWithWorktree, resolveSessionBase } from "./worktree-session.ts";

const valueFlags = new Set(`age-recipient age-recipient-file cache color config config-format
  destination mode output persistent-state progress source use-builtin-age use-builtin-git
  working-tree exclude include`.split(/\s+/));
const booleanFlags = new Set(`debug dry-run force help interactive keep-going no-pager no-tty
  source-path use-builtin-diff verbose version init parent-dirs recursive`.split(/\s+/));
const configFlags = new Set(["cache", "config", "config-format", "destination", "persistent-state", "source", "working-tree"]);
const shortFlags: Record<string, string> = {
  c: "config", D: "destination", n: "dry-run", h: "help", k: "keep-going", o: "output",
  R: "refresh-externals", S: "source", v: "verbose", W: "working-tree",
  x: "exclude", i: "include", P: "parent-dirs", r: "recursive",
};

// Parse only enough to identify apply, dry runs, and config overrides. The original
// argv goes unchanged to chezmoi; unknown flags fail before touching the snapshot.
export function parseApplyInvocation(args: string[]) {
  const invocation = { configArgs: [] as string[], dryRun: false, help: false };
  let version = false;
  let command: string | undefined;
  for (let index = 0; index < args.length; index++) {
    const arg = args[index]!;
    if (arg === "--") break;
    if (!arg.startsWith("-") || arg === "-") {
      if (command === undefined) {
        command = arg;
        if (command !== "apply") return;
      }
      continue;
    }
    const long = arg.startsWith("--");
    let flags = arg.slice(long ? 2 : 1);
    while (flags.length > 0) {
      const equal = flags.indexOf("=");
      const name = long ? flags.split("=", 1)[0]! : shortFlags[flags[0]!] ?? flags[0]!;
      let value = long
        ? (equal < 0 ? undefined : flags.slice(equal + 1))
        : (flags[1] === "=" ? flags.slice(2) : undefined);
      flags = long || value !== undefined ? "" : flags.slice(1);
      if (valueFlags.has(name)) {
        if (value === undefined && flags) { value = flags; flags = ""; }
        value ??= args[++index];
        if (value === undefined) throw new Error(`--${name} requires a value`);
        if (configFlags.has(name)) invocation.configArgs.push(`--${name}`, value);
      } else if (booleanFlags.has(name)) {
        if (value !== undefined && !/^(?:true|false|TRUE|FALSE|True|False|t|f|T|F|0|1)$/.test(value)) {
          throw new Error(`invalid boolean for --${name}: ${value}`);
        }
        const enabled = value === undefined || /^(?:true|t|1)$/i.test(value);
        if (name === "dry-run") invocation.dryRun = enabled;
        if (name === "help") invocation.help = enabled;
        if (name === "version") version = enabled;
      } else if (name !== "refresh-externals") {
        if (command === undefined) return;
        throw new Error(`unsupported option while coordinating worktree apply: --${name}`);
      }
    }
  }
  invocation.help ||= version;
  return command === "apply" ? invocation : undefined;
}

export async function runCoordinatedChezmoi(args: string[], options: {
  homeDir?: string;
  sessionBase?: string;
} = {}): Promise<CommandResult> {
  const homeDir = options.homeDir ?? os.homedir();
  const sessionBase = options.sessionBase ?? resolveSessionBase(process.platform, homeDir, process.env);
  const execute = (coordinated = false): CommandResult => {
    const result = spawnSync("chezmoi", args, {
      stdio: "inherit",
      env: coordinated ? { ...process.env, CHEZMOI_WORKTREE_COORDINATED: sessionBase } : process.env,
    });
    return { ...result, stdout: Buffer.alloc(0), stderr: Buffer.alloc(0) };
  };
  const invocation = parseApplyInvocation(args);
  if (invocation === undefined || invocation.help) return execute();
  if (invocation.dryRun) return execute(true);
  const config = JSON.parse(requireSuccess(runCommand("chezmoi", [
    ...invocation.configArgs, "dump-config", "--format=json",
  ])).stdout.toString("utf8"));
  if (path.resolve(config.destDir) !== path.resolve(homeDir)) return execute();
  return applyMainWithWorktree({
    destinationDir: homeDir,
    sessionBase,
    apply: () => execute(true),
  });
}

export function guardUncoordinatedApply(env: NodeJS.ProcessEnv = process.env): void {
  const homeDir = os.homedir();
  if (path.resolve(env.CHEZMOI_DEST_DIR ?? homeDir) !== path.resolve(homeDir)) return;
  const sessionBase = resolveSessionBase(process.platform, homeDir, env);
  if (env.CHEZMOI_WORKTREE_COORDINATED === sessionBase) return;
  if (["active", "operation"].some((name) => existsSync(path.join(sessionBase, name)))) {
    throw new Error("An active worktree needs the coordinated chezmoi apply. Reload your shell, then run chezmoi apply; or run bun run scripts/chezmoi.ts apply from the checkout. Other apply-producing commands require worktree:revert first.");
  }
}

if (import.meta.main) {
  try {
    if (process.argv[2] === "--guard") {
      guardUncoordinatedApply();
    } else {
      const result = await runCoordinatedChezmoi(process.argv.slice(2));
      if (result.error) throw result.error;
      if (result.signal) process.kill(process.pid, result.signal);
      process.exitCode = result.status ?? 1;
    }
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : error}\n`);
    process.exitCode = 1;
  }
}
