import { expect, test } from "bun:test";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const zsh = process.env.ZSH_TEST_BIN || Bun.which("zsh");
const source = resolve(import.meta.dir, "../home");

/** Builds an isolated HOME with Zsh dotfiles, a stub-tool PATH, and shell helpers. */
function fixture() {
  const root = mkdtempSync(join(tmpdir(), "mac zsh-"));
  const home = join(root, "home");
  const bin = join(root, "brew prefix/bin");
  mkdirSync(home);
  mkdirSync(bin, { recursive: true });
  mkdirSync(join(root, "tmp"));
  for (const name of ["zprofile", "zshrc", "zsh_aliases"]) {
    let text = readFileSync(join(source, `dot_${name}`), "utf8");
    if (name === "zprofile") {
      // Simulate both Mac prefixes without touching real Homebrew installations.
      text = text.replaceAll("/opt/homebrew", `'${join(root, "armbrew").replaceAll("'", "'\\''")}'`)
        .replaceAll("/usr/local", `'${join(root, "intelbrew").replaceAll("'", "'\\''")}'`);
    }
    writeFileSync(join(home, `.${name}`), text);
  }
  const env: Record<string, string> = {
    HOME: home, ZDOTDIR: home, PATH: `${bin}:/usr/bin:/bin`,
    TERM: "xterm-256color", TERM_PROGRAM: "ghostty", TMPDIR: join(root, "tmp"),
    ZSH_TEST_BREW_PREFIX: join(root, "brew prefix"),
  };
  // Allows an extracted test-only zsh without installing it on the host.
  if (process.env.ZSH_TEST_FPATH) env.FPATH = process.env.ZSH_TEST_FPATH;
  if (process.env.ZSH_TEST_MODULE_PATH) {
    env.ZSH_TEST_MODULE_PATH = process.env.ZSH_TEST_MODULE_PATH;
    writeFileSync(join(home, ".zshenv"), 'module_path=("$ZSH_TEST_MODULE_PATH" $module_path)\n');
  }
  return {
    root, home, env,
    command(name: string, body: string) {
      const file = join(bin, name);
      writeFileSync(file, `#!/bin/sh\n${body}\n`);
      chmodSync(file, 0o755);
    },
    run(script: string, login = false, overrides: Record<string, string> = {}) {
      const result = Bun.spawnSync([zsh!, login ? "-lic" : "-ic", script], {
        env: { ...env, ...overrides }, cwd: home,
      });
      expect(result.stderr.toString()).toBe("");
      return { code: result.exitCode, output: result.stdout.toString() };
    },
    close() { rmSync(root, { recursive: true, force: true }); },
  };
}

test.skipIf(!zsh)("zsh starts with optional tools absent and uses Mac aliases", () => {
  const f = fixture();
  try {
    const result = f.run("print -r -- $aliases[ls] $aliases[rm]; (( $+functions[compdef] ))");
    expect(result.code).toBe(0);
    expect(result.output).toContain("ls -G rm -Iv");
  } finally { f.close(); }
});

test.skipIf(!zsh)("login and non-login startup recover Brew prefix and completions from PATH", () => {
  const f = fixture();
  try {
    mkdirSync(join(f.env.ZSH_TEST_BREW_PREFIX!, "share/zsh/site-functions"), { recursive: true });
    f.command("brew", 'case "$1" in --prefix) printf "%s\\n" "$ZSH_TEST_BREW_PREFIX" ;; shellenv) : ;; esac');
    for (const login of [false, true]) {
      const result = f.run(String.raw`
        source "$ZDOTDIR/.zshrc"
        [[ $HOMEBREW_PREFIX == $ZSH_TEST_BREW_PREFIX ]] || exit 1
        [[ $fpath[1] == "$HOMEBREW_PREFIX/share/zsh/site-functions" ]] || exit 2
        typeset -Ua unique_path unique_fpath
        unique_path=($path); unique_fpath=($fpath)
        (( $#path == $#unique_path && $#fpath == $#unique_fpath && $+functions[compdef] ))
      `, login);
      expect(result.code).toBe(0);
    }
  } finally { f.close(); }
});

test.skipIf(!zsh)("history filter matches full Bash HISTIGNORE entries and keeps argument variants", () => {
  const f = fixture();
  try {
    const result = f.run(String.raw`
      for line in a ab ls ll la cd pwd exit clear history bg fg; do
        _dotfiles_history_filter "$line"$'\n' && exit 1
      done
      for line in 'ls ' 'ls -l' 'echo hello' $'echo one\necho two'; do
        _dotfiles_history_filter "$line"$'\n' || exit 2
      done
      [[ -o histignorespace && -o histignorealldups && -o incappendhistory && -o extendedhistory ]]
    `);
    expect(result.code).toBe(0);
  } finally { f.close(); }
});

test.skipIf(!zsh)("bare history lists entries older than the last sixteen commands", () => {
  const f = fixture();
  try {
    const commands = Array.from({ length: 25 }, (_, i) => `: history-event-${i}`);
    const result = Bun.spawnSync([zsh!, "-i"], {
      env: f.env, cwd: f.home,
      stdin: new TextEncoder().encode([...commands, "history", "exit", ""].join("\n")),
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toContain(": history-event-0\n");
    expect(result.stdout.toString()).toContain(": history-event-24\n");
  } finally { f.close(); }
});

test.skipIf(!zsh)("native ARM and Rosetta shells select the matching Brew with both installed", () => {
  const f = fixture();
  try {
    const arm = join(f.root, "armbrew");
    const intel = join(f.root, "intelbrew");
    for (const prefix of [arm, intel]) {
      mkdirSync(join(prefix, "bin"), { recursive: true });
      const brew = join(prefix, "bin/brew");
      writeFileSync(brew, '#!/bin/sh\ncase "$1" in --prefix) printf "%s\\n" "${0%/bin/brew}" ;; shellenv) : ;; esac\n');
      chmodSync(brew, 0o755);
    }
    const profile = readFileSync(join(f.home, ".zprofile"), "utf8");
    for (const cpu of ["arm64", "aarch64", "x86_64"]) {
      writeFileSync(join(f.home, ".zprofile"), `CPUTYPE=${cpu}\n${profile}`);
      const result = f.run('print -r -- "PREFIX=$HOMEBREW_PREFIX"', false, { PATH: `${intel}/bin:/usr/bin:/bin` });
      expect(result.output).toContain(`PREFIX=${cpu === "x86_64" ? intel : arm}\n`);
    }
  } finally { f.close(); }
});

test.skipIf(!zsh)("agent wrappers preserve status, arguments, stdin, and parent editor settings", () => {
  const f = fixture();
  try {
    f.command("nvim", ":");
    for (const name of ["claude", "codex", "opencode"]) {
      f.command(name, 'printf "<%s>" "$EDITOR" "$VISUAL" "$@"; /bin/cat; exit 7');
      const result = f.run(`EDITOR='original editor'; VISUAL='original visual'; ${name} 'model name' -- '-x' < /dev/null; code=$?; print -r -- "|$code|$EDITOR|$VISUAL"`);
      expect(result.output).toContain("<nvim --cmd let[g:dotfiles_minimal]=[v:true]><nvim --cmd let[g:dotfiles_minimal]=[v:true]><model name><--><-x>|7|original editor|original visual");
      const piped = f.run(`print -rn -- 'pipeline text' | ${name}; exit 0`);
      expect(piped.output).toContain("pipeline text");
    }
  } finally { f.close(); }
});

test.skipIf(!zsh)("Yazi wrapper preserves directories and exit status and bypasses rm alias", () => {
  const f = fixture();
  try {
    f.command("yazi", 'for arg; do case "$arg" in --cwd-file=*) printf "%s" "$ZSH_TEST_CWD" > "${arg#--cwd-file=}" ;; esac; done; exit "${ZSH_TEST_YAZI_STATUS:-0}"');
    for (const name of ["space dir", "quote' and \\", "embedded\nnewline", "trailing\n"]) {
      const dir = join(f.home, name);
      mkdirSync(dir);
      const result = f.run('y && [[ $PWD == $ZSH_TEST_CWD ]]', false, { ZSH_TEST_CWD: dir });
      expect(result.code).toBe(0);
      expect(readdirSync(f.env.TMPDIR!)).toEqual([]);
    }
    const result = f.run('y && [[ $PWD == $HOME ]]', false, { ZSH_TEST_CWD: "" });
    expect(result.code).toBe(0);
    const dir = join(f.home, "failed exit");
    mkdirSync(dir);
    const failed = f.run('y && exit 99; rc=$?; [[ $PWD == $ZSH_TEST_CWD ]] || exit 98; exit $rc',
      false, { ZSH_TEST_CWD: dir, ZSH_TEST_YAZI_STATUS: "3" });
    expect(failed.code).toBe(3);
    expect(readdirSync(f.env.TMPDIR!)).toEqual([]);
  } finally { f.close(); }
});

test.skipIf(!zsh)("vi shortcuts survive integration setup", () => {
  const f = fixture();
  try {
    const result = f.run("bindkey -M viins jk; bindkey -M vicmd gl; bindkey -M vicmd gh; bindkey -M viins '^L'; bindkey -M vicmd '^L'; bindkey -M viins '^?'; bindkey -M viins '^H'; bindkey -M viins '^W'; bindkey -M viins '^U'");
    expect(result.output).toContain('"jk" vi-cmd-mode');
    expect(result.output).toContain('"gl" end-of-line');
    expect(result.output).toContain('"gh" beginning-of-line');
    expect(result.output.match(/clear-screen/g)).toHaveLength(2);
    expect(result.output).toContain('"^?" backward-delete-char');
    expect(result.output).toContain('"^H" backward-delete-char');
    expect(result.output).toContain('"^W" backward-kill-word');
    expect(result.output).toContain('"^U" backward-kill-line');
  } finally { f.close(); }
});

test.skipIf(!zsh)("optional integrations use native zsh and Atuin retains insert-mode Ctrl-R", () => {
  const f = fixture();
  try {
    f.command("fzf", 'test "$1" = --zsh || exit 1; printf "%s\\n" "bindkey -M viins ^R history-incremental-search-backward"');
    f.command("atuin", 'test "$*" = "init zsh" || exit 1; printf "%s\\n" "bindkey -M viins ^R up-line-or-history"');
    f.command("zoxide", 'test "$*" = "init zsh" || exit 1');
    f.command("fnm", 'test "$*" = "env --shell zsh" || test "$*" = "completions --shell zsh" || exit 1');
    f.command("uv", 'test "$*" = "generate-shell-completion zsh" || exit 1');
    f.command("uvx", 'test "$*" = "--generate-shell-completion zsh" || exit 1');
    f.command("rbenv", 'test "$*" = "init - --no-rehash zsh" || exit 1');
    f.command("delta", ":");
    f.command("fd", ":");
    f.command("eza", ":");
    f.command("bat", ":");
    f.command("starship", 'test "$*" = "init zsh" || exit 1; printf "%s\\n" "PROMPT=starship"');
    const result = f.run('bindkey -M viins ^R; print -r -- "$FZF_DEFAULT_COMMAND|$DELTA_FEATURES|$PROMPT|$aliases[lt]|$aliases[cat]"');
    expect(result.output).toContain('"^R" up-line-or-history');
    expect(result.output).toContain("fd . --hidden --exclude .git|+side-by-side|starship|eza -alF --tree --level=2 --git --icons|bat --paging=never");
    const vscode = f.run('print -r -- $PROMPT', false, { TERM_PROGRAM: "vscode" });
    expect(vscode.output).toContain("%1v");
  } finally { f.close(); }
});

test.skipIf(!zsh)("WezTerm marker keeps direct and tmux escape sequences", () => {
  const f = fixture();
  try {
    expect(f.run(":").output).toBe("\x1b]1337;SetUserVar=IS_TMUX=\x07");
    expect(f.run(":", false, { TMUX: "/tmp/test,1,0" }).output)
      .toBe("\x1bPtmux;\x1b\x1b]1337;SetUserVar=IS_TMUX=dHJ1ZQ==\x07\x1b\\");
    const result = Bun.spawnSync([zsh!, "-c", "print -r -- noninteractive"], { env: f.env });
    expect(result.exitCode).toBe(0);
    expect(result.stderr.toString()).toBe("");
    expect(result.stdout.toString()).toBe("noninteractive\n");
  } finally { f.close(); }
});

test.skipIf(!zsh)("alert passes prior status and quoted history text as notification arguments", () => {
  const f = fixture();
  try {
    f.command("osascript", 'printf "<%s>" "$@"; /bin/cat');
    const message = String.raw`: 'quoted "text" \ path'; false`;
    const result = Bun.spawnSync([zsh!, "-i"], {
      env: f.env, cwd: f.home,
      stdin: new TextEncoder().encode(`echo previous\n${message}; alert\nexit\n`),
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toContain(`<-><${message}><1>`);
    expect(result.stdout.toString()).toContain("display notification (item 1 of argv)");
  } finally { f.close(); }
});
