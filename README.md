# Dotfiles

Cross-platform dev configs managed with [chezmoi](https://chezmoi.io/).

## Quick Start

```bash
chezmoi init https://github.com/trinhlehainam/Dotfiles.git
chezmoi diff
chezmoi apply
```

## Test a Worktree

From the worktree you want to test:

```bash
pnpm run worktree:diff
pnpm run worktree:apply
# Test applications normally in your real HOME.
pnpm run worktree:revert
```

Apply saves current managed targets, including local edits, as a temporary chezmoi
source. Revert restores that snapshot, overwrites test edits, and verifies restoration
before deleting it.

- One session at a time. Both commands ask for confirmation; `--yes` skips the prompt.
- Keep the worktree until you revert. Stop apps that write configs before reverting;
  reload or restart apps afterward.
- Failed apply triggers automatic recovery. If recovery fails, the snapshot stays at
  the printed path. Fix the reported problem and run `pnpm run worktree:revert` again.
- If preparation was interrupted, `worktree:revert` prints cleanup instructions. Stop any
  running apply process before removing the incomplete session; never delete a ready snapshot.
- Revert stops if a new directory contains uncaptured files. Move those files elsewhere
  and retry.

Recovery covers managed file contents, symlinks, directory presence, and permissions
chezmoi can represent. Unsupported source features and filesystem layouts are rejected.
App state, caches, plugin installations, and other filesystem metadata are outside scope.
Templates run during source inspection. Use trusted templates; their command side effects
are outside recovery scope.

## Where To Edit

- Neovim: `home/.shared-configs/nvim/`
- Yazi: `home/.shared-configs/yazi/`
- WezTerm: `home/dot_config/wezterm/`
- Windows configs: `home/AppData/`

`home/dot_config/` maps to `~/.config/`.

Neovim and Yazi templates under `home/dot_config/` and `home/AppData/` are generated.
Edit their raw files under `.shared-configs/`; manual template edits are overwritten.

The hook in `home/.chezmoi.toml.tmpl` runs [scripts/reconcile-configs.ts](scripts/reconcile-configs.ts)
before chezmoi reads the source. It generates include wrappers and records stale targets
in `.chezmoiremove`. Tools and platform paths are defined in [scripts/tools.config.ts](scripts/tools.config.ts).

If you change the hook template, regenerate your active chezmoi config manually;
the repository does not manage that file.

## Requirements

- chezmoi + git
- A package manager (brew/winget/apt/…)
- pnpm for dependencies
- Bun for the repository scripts

## Development

```bash
pnpm install
pnpm run reconcile:configs
pnpm test
pnpm run typecheck
```

Use `chezmoi -v` or `chezmoi --debug` for more detailed reconciler logs.

## Adding a New Tool

1. Create directory: `home/.shared-configs/<tool>/`
2. Drop config files into it
3. Add entry to `scripts/tools.config.ts`:

```ts
{
  name: "bat",
  source: ".shared-configs/bat",
  targets: {
    unix: { wrapperRoot: "dot_config/bat", targetPrefix: ".config/bat" },
    windows: { wrapperRoot: "AppData/Local/bat", targetPrefix: "AppData/Local/bat" },
  },
}
```
