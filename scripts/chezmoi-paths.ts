import { readFileSync } from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";

const defaultSourceRoot = "home";

export type PathOverrides = {
  sourceDir?: string;
  workingTree?: string;
};

export type BasePathOptions = {
  repoRoot?: string;
  sourceStateRoot?: string;
};

export function tokenizeShellWords(
  value: string,
  options: { preserveBackslashes?: boolean } = {},
): string[] {
  const tokens: string[] = [];
  let current = "";
  let quote: '"' | "'" | null = null;
  let tokenWasQuoted = false;

  function pushCurrent(): void {
    if (current.length > 0 || tokenWasQuoted) {
      tokens.push(current);
      current = "";
      tokenWasQuoted = false;
    }
  }

  for (let index = 0; index < value.length; index += 1) {
    const character = value.charAt(index);

    if (quote === null) {
      if (/\s/.test(character)) {
        pushCurrent();
        continue;
      }

      if (character === '"' || character === "'") {
        quote = character;
        tokenWasQuoted = true;
        continue;
      }

      if (character === "\\") {
        if (index + 1 < value.length) {
          const nextCharacter = value.charAt(index + 1);
          if (
            !options.preserveBackslashes ||
            nextCharacter === "\\" ||
            nextCharacter === '"' ||
            nextCharacter === "'" ||
            /\s/.test(nextCharacter)
          ) {
            current += nextCharacter;
            index += 1;
            continue;
          }
        }

        current += character;
        continue;
      }

      current += character;
      continue;
    }

    if (character === quote) {
      quote = null;
      continue;
    }

    if (character === "\\" && quote === '"') {
      if (index + 1 < value.length) {
        const nextCharacter = value.charAt(index + 1);
        if (
          !options.preserveBackslashes ||
          nextCharacter === "\\" ||
          nextCharacter === '"' ||
          nextCharacter === "$" ||
          nextCharacter === "`"
        ) {
          current += nextCharacter;
          index += 1;
          continue;
        }
      }

      current += character;
      continue;
    }

    current += character;
  }

  pushCurrent();
  return tokens;
}

export function resolvePathOverrides(rawChezMoiArgs: string): PathOverrides {
  const { values } = parseArgs({
    args: tokenizeShellWords(rawChezMoiArgs, { preserveBackslashes: true }),
    options: {
      source: { type: "string", short: "S" },
      "working-tree": { type: "string", short: "W" },
    },
    strict: false,
    allowPositionals: true,
  });

  return {
    sourceDir: values.source as string | undefined,
    workingTree: values["working-tree"] as string | undefined,
  };
}

export function resolveSourceStateRoot(repoRoot: string): string {
  try {
    const configuredRoot = readFileSync(path.join(repoRoot, ".chezmoiroot"), "utf8").trim();
    return path.join(repoRoot, configuredRoot || defaultSourceRoot);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      throw error;
    }

    return path.join(repoRoot, defaultSourceRoot);
  }
}

export function resolveBasePaths(
  options: BasePathOptions,
  defaultRepoRoot: string,
  rawChezMoiArgs: string = process.env.CHEZMOI_ARGS ?? "",
): { repoRoot: string; sourceStateRoot: string } {
  const pathOverrides = resolvePathOverrides(rawChezMoiArgs);
  const repoRoot = options.repoRoot ?? pathOverrides.workingTree ?? defaultRepoRoot;

  return {
    repoRoot,
    sourceStateRoot:
      options.sourceStateRoot ?? pathOverrides.sourceDir ?? resolveSourceStateRoot(repoRoot),
  };
}
