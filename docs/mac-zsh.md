# macOS zsh

Use macOS's `/bin/zsh` with Bash-style aliases, vi keys, and optional tool
integrations. Chezmoi installs these shell files only on macOS.

## Set up

You need Chezmoi and Bun; the repo's existing Chezmoi hook uses Bun.
Homebrew and other tools load when installed.
Your login shell should be `/bin/zsh`; check with `echo "$SHELL"`.

Run these commands from the repository root (the folder containing
`.chezmoiroot`). `-S "$PWD"` selects this checkout, including a feature worktree.
First, review the changes:

```sh
chezmoi -S "$PWD" diff ~/.zprofile ~/.zshrc ~/.zsh_aliases
```

Applying replaces these three files. If the diff removes settings you need,
add them to the matching source file in `home/` first. Then apply and restart:

```sh
chezmoi -S "$PWD" apply ~/.zprofile ~/.zshrc ~/.zsh_aliases
exec /bin/zsh -l
```

## Check it works

Check syntax; success produces no output:

```sh
/bin/zsh -n ~/.zprofile
/bin/zsh -n ~/.zshrc
/bin/zsh -n ~/.zsh_aliases
```

In a new terminal, try Tab completion and `sleep 1; alert`. If the notification
is missing, check Notification Center settings.

## Daily use

| Key or command | Action |
| --- | --- |
| `jk` | Enter vi command mode. |
| `gh` / `gl` | Move to the start / end of the line in command mode. |
| Ctrl-L | Clear the screen in either mode. |
| `history` | Show all loaded history with timestamps. |
| `v`, `vim`, `vi` | Open Neovim, if installed. |
| `y` | Open Yazi and keep its final directory, if installed. |
| `sleep 1; alert` | Notify when a command succeeds or fails. |

Installed eza, bat, and ripgrep replace `ls`, `cat`, and `grep`. fzf, Atuin,
Starship, zoxide, fnm, uv/uvx, and rbenv also load when available. With fzf and
Atuin together, Ctrl-R uses Atuin in insert mode and fzf in command mode.
Ghostty supplies its own shell integration.

## Differences from Bash

- History uses `~/.zsh_history`: 10,000 events in memory and a file periodically
  trimmed to 50,000. Existing Bash history is not imported. Atuin has separate
  history filters; configure its `history_filter` if needed.
- Tab completion ignores case and corrects minor typos. `cd` does not correct
  typos when you press Enter, and `$VAR` paths stay unexpanded in the edit buffer.
- Without eza, Apple's `ls` has no directory-first sorting. `rm -Iv` prompts once
  for recursive removal or more than three files; it requires macOS 12.3+.
- Homebrew prefers `/opt/homebrew` in native Apple Silicon shells and
  `/usr/local` on Intel/Rosetta. A custom prefix can come from `PATH`.
- Linux/WSL settings and Bash WakaTime are omitted. Terminal time tracking needs
  separate setup.

## Source files

| Repository file | Installed file | Purpose |
| --- | --- | --- |
| [dot_zprofile](../home/dot_zprofile) | `~/.zprofile` | Homebrew environment. |
| [dot_zshrc](../home/dot_zshrc) | `~/.zshrc` | Shell settings and integrations. |
| [dot_zsh_aliases](../home/dot_zsh_aliases) | `~/.zsh_aliases` | Command aliases. |

For automated checks, run `bun test ./scripts/mac-zsh.test.ts` with zsh available.
Linux checks do not verify Apple's tools, notifications, or terminal rendering;
check those on the Mac.

References: [zsh startup](https://zsh.sourceforge.io/Doc/Release/Files.html),
[Homebrew completion](https://docs.brew.sh/Shell-Completion),
[Atuin settings](https://docs.atuin.sh/main/configuration/config/).
