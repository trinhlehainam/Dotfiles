# macOS zsh

The Mac configuration ports `home/dot_bashrc` and `home/dot_bash_aliases` to native
zsh. Chezmoi manages these files only on macOS:

- `home/dot_zprofile` → `~/.zprofile`: Homebrew login environment.
- `home/dot_zshrc` → `~/.zshrc`: interactive settings and optional integrations.
- `home/dot_zsh_aliases` → `~/.zsh_aliases`: commands matching the Bash aliases.

Use Apple's bundled `/bin/zsh`. No shell framework, Homebrew zsh,
`bash-completion`, GNU coreutils, or extra font is required for this shell port.
Ghostty supplies its own shell integration. The existing Neovim package audit
and its language-install caveats remain separate from this shell change.

## Apply on the Mac

From the updated Chezmoi checkout, review and apply just the shell files:

```sh
chezmoi diff ~/.zprofile ~/.zshrc ~/.zsh_aliases
chezmoi apply ~/.zprofile ~/.zshrc ~/.zsh_aliases
exec /bin/zsh -l
```

The repo's existing Chezmoi hook needs Bun. This change does not install packages
or change the login shell. Keep macOS's default zsh. To check syntax on the Mac:

```sh
/bin/zsh -n ~/.zprofile
/bin/zsh -n ~/.zshrc
/bin/zsh -n ~/.zsh_aliases
```

Homebrew prefers `/opt/homebrew` in native Apple Silicon shells, then `/usr/local`
for Intel/Rosetta; `PATH` supplies a custom prefix if no matching default exists.
This avoids selecting an old Intel Brew after Migration Assistant on an ARM Mac.
An independent interactive non-login shell also loads the profile when its Brew
environment is missing. The completion directory is added explicitly before
`compinit`, including when `brew shellenv` emits nothing for an inherited PATH.
Insecure completion paths are skipped; run `compaudit` to inspect them.

## Bash-to-zsh mapping

Every active Bash feature is accounted for below. Platform and shell differences
are explicit; this is a functional port, not identical Bash parsing or history.

| Bash setting or feature | macOS zsh behavior |
| --- | --- |
| Interactive-only `.bashrc` | `.zshrc` with an interactive guard; noninteractive commands get no startup output. |
| Visible Readline bell | Native `ZBEEP` reverse-video sequence from the zsh manual; visual effect depends on the terminal. |
| `HISTSIZE=10000`, `HISTFILESIZE=50000` | `HISTSIZE=10000`, `SAVEHIST=50000`, separate `~/.zsh_history`. zsh counts events; Bash's file limit counts lines. Sessions load the newest 10,000 events; the file is periodically trimmed to 50,000 and can grow briefly before a rewrite. |
| `HISTTIMEFORMAT='%F %T '` | `EXTENDED_HISTORY` saves timestamps; `history` lists all available entries with `fc -l -t '%F %T'`. Explicit arguments follow zsh `fc`, not Bash `history`. |
| `erasedups:ignorespace` | `HIST_IGNORE_ALL_DUPS`, `HIST_IGNORE_SPACE`. Already appended duplicates disappear from disk during a later rewrite. |
| `HISTIGNORE` | `zshaddhistory` excludes the same exact names and one/two-character inputs; `ls -l` and `ls ` remain eligible. |
| `histappend`, `history -a` before prompts | `INC_APPEND_HISTORY`; new entries append immediately, without importing another session's history. |
| `histverify` | `HIST_VERIFY`: history expansions return to the edit buffer. |
| `checkwinsize` | Native zsh/ZLE terminal resize handling. |
| `autocd` | `AUTO_CD`; directory names can be entered directly. |
| `cdspell`, `dirspell`, `direxpand` | Native `_complete` / `_approximate` completion works through `$VAR/` and `~/` and corrects one error on Tab. Bash's in-buffer variable rewrite and automatic correction of a misspelled `cd` argument on Enter are not reproduced. Broad `CORRECT_ALL` is intentionally absent. |
| `globstar`, `nocaseglob` | Native `**/`, `NO_CASE_GLOB`; `NOMATCH` disabled for Bash-like unmatched patterns. Other zsh glob rules remain native. |
| `cmdhist`, `lithist` | Native zsh multiline history; serialization differs from Bash. Existing Bash history is not imported. |
| Seven `LESS_TERMCAP_*` values | Identical exported ANSI strings. |
| Debian `lesspipe`, chroot marker | Linux-specific paths omitted; no lesspipe package added. |
| `user@host:directory` prompt and mode indicator | Native prompt with `(ins)` / `(cmd)` and additive ZLE hooks; same colour gate and `$` / root `#` suffix as Bash. Starship takes over when present. |
| xterm/rxvt title | Additive `precmd` title hook with the built-in prompt, matching Bash. Ghostty uses its own title integration. |
| `alert` / `notify-send` | `alert` uses macOS `osascript` notifications, passing the current history line and prior status as arguments, stripping trailing `; alert` like Bash. Notification Center settings govern visibility. No notifier package needed. |
| System and Brew Bash completions | Brew `fpath`, secure `compinit -i`, native zsh completions. No Bash scripts sourced. |
| Ignore completion case, show matches on first Tab | `matcher-list`, `AUTO_LIST`, no `LIST_AMBIGUOUS`/`BASH_AUTO_LIST`/`LIST_BEEP`: list without ringing the bell. |
| Vi mode, Ctrl-L in both maps, `jk`, `gl`, `gh` | Same shortcuts via `bindkey`; configured before fzf and Atuin. Insert-mode Backspace, Ctrl-W and Ctrl-U delete past the insertion point, matching Readline. |
| Interactive comments and `rm *` behavior | `INTERACTIVE_COMMENTS` and `RM_STAR_SILENT` match Bash; removal confirmation remains controlled by the `rm -I` alias. |
| Linuxbrew path, forced brewed curl, developer unset | Native Mac prefix selection. Curl forcing and overriding inherited developer mode omitted; these are unnecessary for Mac bootstrap. |
| Conditional `.bash_aliases` | Conditional `.zsh_aliases` with Mac flags, described below. |
| `EDITOR=nvim`; `claude`, `codex`, `opencode` wrappers | Same guarded editor and per-invocation `VISUAL`/`EDITOR` string; stdin, arguments, and exit status preserved. |
| `CLICOLOR`, custom `LS_COLORS` | Identical values. Apple's `ls` does not use GNU extension colors; tools consuming `LS_COLORS` can still use them. |
| `grep=rg`, system grep fallback | Same guarded replacement; ripgrep's flags/behavior differ from POSIX grep, as in Bash. |
| fd candidate list for fzf | Same two `FZF_*_COMMAND` exports when both tools exist; fd remains optional. |
| `fzf --bash` | Guarded `source <(fzf --zsh)`; use current Brew fzf (integration flag requires 0.48+). Without fd, fzf uses its own candidate walker. |
| Starship outside VS Code | Guarded `starship init zsh`; native prompt if missing or in VS Code. Its character module handles vi mode when enabled in the user's Starship config. |
| WezTerm `IS_TMUX` OSC marker | Same initial/prompt marker and tmux passthrough; hooks are additive. Existing tmux attach hook is retained. |
| zoxide | Guarded `zoxide init zsh`, after completion setup. |
| fnm env/completion | Guarded `fnm env --shell zsh` and `fnm completions --shell zsh`; no new automatic directory switching. Brew fnm works without a standalone install. |
| `PNPM_HOME` | Respect existing value; otherwise `$XDG_DATA_HOME/pnpm` or Mac default `~/Library/pnpm`. Existing root and `bin` directories join PATH. |
| bash-preexec + Atuin | Native `atuin init zsh`; no bash-preexec. Loaded after fzf: Atuin takes insert-mode Ctrl-R; command-mode Ctrl-R retains fzf, matching Bash integration defaults. Atuin has its own history store and filters. |
| Delta side-by-side | Same guarded `DELTA_FEATURES=+side-by-side`. |
| bash-wakatime | Bash-only plugin omitted. No zsh plugin installed implicitly; WakaTime's terminal tracking needs separate setup. |
| Yazi `y` wrapper | Same cwd-file flow; portable temp template, newline-safe read, directory check, alias-free cleanup. Like Bash, cleanup determines final status. |
| Cargo env, `~/.local/bin`, uv env | Source existing shell-compatible env scripts; add existing user paths without duplicates, before checking tools. |
| uv and uvx Bash completion | Native zsh completion for each installed binary. |
| rbenv | Guarded `rbenv init - --no-rehash zsh`. |
| Vagrant WSL env/VirtualBox path | WSL-only; omitted on Mac. |
| Herd Lite path and PHP scan directory | Added only if installed; preserve PHP's empty component for the default scan directory. |
| `BUN_INSTALL` and PATH | Respect existing value or `~/.bun`; add standalone bin only if present. Brew Bun needs no second install. |

Optional directories are discovered before tool checks. The directory order is
Bun, Herd Lite, local bin, pnpm bin/root, fnm, Cargo, then inherited paths; fnm
and rbenv subsequently put their selected runtime/shims first. This deliberate
order avoids the Bash startup's accidental failure to discover later PATH tools.
PATH and completion directories are deduplicated in nested shells.

| Bash aliases | zsh equivalents |
| --- | --- |
| `v`, `vim`, `vi` | Same nvim aliases, only if installed. |
| eza `ls`, `ll`, `la`, `l`, `lt`, `llt`, `lls` | Identical, only if eza is installed. |
| GNU ls fallback | `ls -G`, `ls -alFhG`, `ls -aFG`, `ls -FG`. Native Mac fallback has no directory-first sort. Tree/time/size aliases stay eza-only. |
| `cp -iv`, `mv -iv`, `mkdir -pv` | Identical. |
| `rm -Iv` | Identical one-confirmation behavior on macOS 12.3+; current Homebrew-supported macOS versions provide `-I`. |
| bat `cat`, `catp` | Identical, only if bat is installed. |
| `df -h`, `du -h`, optional `free -h` | Identical; free normally absent on Mac. |
| WSL `open=explorer.exe` | Omitted; retain macOS's native `open`. |

Atuin does not inherit the native zsh history exclusions. If using it, configure
its `history_filter` separately for matching short/named-command exclusions.
Leading-space commands are already ignored by Atuin. No Atuin settings are
changed by this port.

## Sources and verification

Checked 2026-11-05 against upstream documentation:

- zsh: [startup](https://zsh.sourceforge.io/Doc/Release/Files.html), [options](https://zsh.sourceforge.io/Doc/Release/Options.html), [history/hooks](https://zsh.sourceforge.io/Doc/Release/Functions.html), [parameters and ZBEEP](https://zsh.sourceforge.io/Doc/Release/Parameters.html), [fc history ranges](https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html), [history array](https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html#The-zsh_002fparameter-Module), [completion](https://zsh.sourceforge.io/Doc/Release/Completion-System.html), [ZLE](https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html), [hook helpers](https://zsh.sourceforge.io/Doc/Release/User-Contributions.html).
- Homebrew: [installation](https://docs.brew.sh/Installation), [support tiers](https://docs.brew.sh/Support-Tiers), [completion](https://docs.brew.sh/Shell-Completion), [shellenv source](https://github.com/Homebrew/brew/blob/main/Library/Homebrew/cmd/shellenv.sh).
- Apple: [ls](https://github.com/apple-oss-distributions/file_cmds/blob/main/ls/ls.1), [rm](https://github.com/apple-oss-distributions/file_cmds/blob/main/rm/rm.1), [mktemp](https://github.com/apple-oss-distributions/shell_cmds/blob/main/mktemp/mktemp.1), [notifications](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/DisplayNotifications.html).
- Integrations: [fzf](https://github.com/junegunn/fzf#setting-up-shell-integration), [Yazi](https://yazi-rs.github.io/docs/quick-start/#shell-wrapper), [Starship](https://starship.rs/guide/), [Atuin](https://docs.atuin.sh/main/configuration/config/), [zoxide](https://github.com/ajeetdsouza/zoxide#installation), [fnm](https://github.com/Schniz/fnm#shell-setup), [uv](https://docs.astral.sh/uv/getting-started/installation/#shell-autocompletion), [rbenv](https://github.com/rbenv/rbenv#how-rbenv-hooks-into-your-shell), [pnpm installer](https://github.com/pnpm/get.pnpm.io/blob/main/install.sh), [Bun](https://bun.com/docs/installation), [PHP scan paths](https://www.php.net/manual/en/configuration.file.php), [WakaTime](https://wakatime.com/terminal), [WezTerm](https://wezterm.org/recipes/passing-data.html), [Ghostty](https://ghostty.org/docs/features/shell-integration).

Run `bun test ./scripts/mac-zsh.test.ts` where zsh is available. Tests use an isolated
HOME and stub tools; `ZSH_TEST_BIN` can select a test binary. Linux runtime checks
do not verify Apple's bundled tools, Notification Center, Ghostty rendering, or
actual Mac startup files. Complete the syntax and interactive checks on the Mac.
