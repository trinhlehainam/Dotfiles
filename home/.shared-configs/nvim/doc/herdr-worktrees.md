# Neovim, Workmux, and Herdr

Use one Neovim per worktree and one central Herdr window for all agents.
Workmux owns Git worktrees and their tmux editor windows. Herdr opens those
existing checkouts and owns the agent terminals.

```text
tmux session
  main            Neovim in the main checkout
  feature-a       Neovim in worktree A
  feature-b       Neovim in worktree B
  agents          Herdr: workspace A → agents; workspace B → agents
  workmux         Worktrees dashboard
```

## Start and navigate

The dotfiles Smug config creates `main`, `workmux`, and `agents`:

```sh
smug start dotfiles
```

For an existing session that lacks the agents window, create it once with
`smug start dotfiles -w agents`. Check `tmux list-windows` first: Smug's window
creation command is not a reusable toggle.

| Action | Keys |
| --- | --- |
| Toggle editor ↔ central Herdr window | `Ctrl+A H` |
| Pick a tmux editor window | `Ctrl+A o` (SessionX) or `Ctrl+A w` |
| Pick an agent across Herdr workspaces | `Ctrl+B g`, then `/` to search |
| Pick a Herdr workspace | `Ctrl+B w` |
| Zoom a Herdr agent pane | `Ctrl+B z` |
| Zoom an outer tmux pane | `Ctrl+A z` |

`H` returns to the last tmux window, which may be the dashboard if that was
your previous window. Keep the central window named `agents`.
Herdr receives `Ctrl+h/j/k/l` and `Alt+,/./u/d`; its own bindings determine
what they do. Ordinary shells retain tmux navigation and resizing.

Use the default local Herdr session from both Neovim and the `agents` window.
Neovim runs directly in tmux; do not nest tmux inside Herdr or invent
`HERDR_ENV`, pane IDs, or workspace IDs. If you deliberately use a named Herdr
session, both processes must inherit the same `HERDR_SESSION`. An inherited
`HERDR_SOCKET_PATH` can override that choice.

## Open a worktree

From the repository, create the checkout and editor with Workmux:

```sh
workmux add feature-a
```

In a shell, open that existing checkout in Herdr. Use absolute paths from
`git worktree list`; for this repository the default directory is `worktrees/`:

```sh
herdr worktree open --cwd /absolute/path/to/repo \
  --path /absolute/path/to/repo/worktrees/feature-a --label feature-a
```

Start Claude, Codex, or another agent in that Herdr workspace. Multiple agents
share its checkout and editor. Give simultaneous independent implementations
different worktrees; use additional agents in the same checkout for review
or investigation.

`workmux open feature-a` reuses the editor window. Herdr also reuses an already
open checkout. Workmux's Worktrees dashboard remains useful; its Agents tab
does not track agents hosted inside Herdr. Do not install Workmux agent status
hooks for those agents.

There are no lifecycle hooks connecting the tools. Herdr being unavailable
must not prevent Workmux from creating an editor. Editor switching and Herdr
workspace switching remain independent.

## Stage context, then continue in Herdr

| Neovim keys | Context |
| --- | --- |
| `<leader>ab` | Reference the whole saved file |
| `<leader>ay` | Reference the saved current line or selected lines |
| `<leader>as` | Stage the current line or selected whole lines, including unsaved edits |

Every send opens a picker, even with one agent. **Choose by workspace and
directory, then check the pane ID.** Agents of the same type have different
pane IDs. The picker covers the whole Herdr session; it does not automatically
bind this editor to its worktree. Herdr's focused workspace can sort first,
even when it belongs to another editor. If this worktree has no agent, cancel
and start one in Herdr.

After choosing, `Ctrl+A H` opens Herdr. The plugin focuses the chosen agent
inside Herdr but does not switch the outer tmux window. Review the draft, add
instructions, and press Enter there. The configured mappings do not submit.
Only stage while the target is idle at its prompt.

Reference mappings refuse unsaved, missing, and special buffers. Save first,
or use `<leader>as` for unsaved text. References are relative to the source
checkout: choosing a different worktree can reference its version of the file.

Selected content uses whole lines, including characterwise or blockwise
selections. This avoids an upstream UTF-8 selection bug. Content is written
to a mode-0600 file under Neovim's cache directory, `herdr-context/<editor-pid>/`; only its
path is typed into the agent. The agent needs permission to read that local
directory. Files survive Neovim exit and are not automatically deleted; remove
old context files once agents no longer need them.

This is a tested external-editor configuration of a plugin whose README
recommends running inside Herdr. Its picker does not revalidate the agent
process immediately before writing. If the agent exits while the picker is
open, cancel and reopen it. The guards above apply to these mappings, not to
every upstream command or composer action. The Herdr companion plugin is not
required. Do not install the similarly named `mcuste` plugin alongside it.

## Review and finish

Return to Neovim and use the existing `:DiffviewOpen`, Neogit, or gitsigns.
Clean buffers reload external edits on focus or buffer entry. Dirty buffers
keep local changes; compare with the file on disk before saving.
Neovim's own file checks may also show a changed-on-disk warning for dirty
buffers. Keep the buffer contents until you have compared both versions.

The embedded Claude, Codex, and OpenCode Neovim plugins are disabled. Conversations
and edit approvals now happen in Herdr. Diffview reviews changes already on
disk; it does not replace an agent's approval prompt before writing.

The three disabled specs also overwrite older deployed configurations when
applying from a fresh Chezmoi worktree. Keeping these small files prevents old
agent mappings from surviving the migration as unmanaged files.

Before removing or merging a worktree:

1. Save and quit its Neovim editor.
2. Finish or stop its agents and close that workspace in Herdr. Closing the
   workspace leaves the Git checkout on disk.
3. Use `workmux remove feature-a` or the appropriate Workmux merge command.
   Removal normally also deletes the branch; use `--keep-branch` to preserve it.

`workmux close feature-a` closes only the editor window. It leaves the checkout
and Herdr agents running. Renaming or moving a checkout requires reopening the
matching workspace in Herdr. Never remove a checkout while agents still use it.

## Versions and configuration

Tested with tmux 3.8, Neovim 0.12.6, Herdr 0.9.5, Workmux 0.1.276, and Smug
0.3.19. The Neovim plugin is pinned at `2e99ef05c52e1a8ee71b630612a0f8ac18a9638e`.
Recheck context routing and keyboard behavior before upgrading the bridge.

The global Workmux config provides the editor-only default. A project's own
`.workmux.yaml` can override it; this repository explicitly uses the same layout.
Happier and automatic cross-tool workspace synchronization are not configured.

## Validation

Verified on 2026-10-18 in temporary directories with private tmux and Herdr
servers. Existing user sessions were not used for the experiments.

- `make test` in the Neovim source directory: 121 tests passed.
- `bun test scripts/reconcile-configs.test.ts scripts/agent-prompt-editor.test.ts`:
  42 tests passed.
- Chezmoi rendered into a temporary home, replaced old agent plugin specs,
  and the full rendered Neovim configuration started successfully.
- Workmux created two editor worktrees; repeated opens reused the windows.
  Closing an editor preserved its agents. Closing Herdr workspaces preceded
  checkout removal, and Workmux remained usable with Herdr stopped.
- A real tmux client exercised the window toggle, SessionX, all eight key
  forwarding bindings, smart-splits, and clean/dirty file refresh after focus.
- Context reached the selected pane with Herdr focused on another worktree.
  Duplicate agent types, cancellation, one/zero agents, reference guards,
  UTF-8, control bytes, and oversized payloads were checked.
- Lazy installed the shipped repository-and-commit spec. Its first visual send
  worked; concurrent editors kept distinct context files even when forced to
  generate identical filenames. Files remained readable after editor exit.
- A real Claude Code Opus 5.5 max terminal displayed both kinds of draft without
  submission. Other agent transports used synthetic terminal receivers in this
  implementation test; model execution and cache-read permissions were not tested.

Claude Code `claude-opus-5-5` with `--effort max` reviewed the design and diff.
Its reference and focus-check feedback is included. The final review found no
blocking code defects and requested additional runtime checks, covered above.

Sources: [Herdr CLI](https://herdr.dev/docs/cli-reference/),
[Herdr context plugin](https://github.com/makyinmars/herdr-context.nvim),
[Workmux configuration](https://workmux.raine.dev/guide/configuration/),
[Smug](https://github.com/ivaaaan/smug).
