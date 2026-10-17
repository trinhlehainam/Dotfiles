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
| Select an editor or Herdr tmux window | `Ctrl+A 1/2/3/…` (its window number) |
| Pick a tmux window from a list | `Ctrl+A o` (SessionX) or `Ctrl+A w` |
| Pick an agent across Herdr workspaces | `Ctrl+B g`, then `/` to search |
| Pick a Herdr workspace | `Ctrl+B w` |
| Move between Herdr panes | `Ctrl+B`, then `h/j/k/l` |
| Zoom a Herdr agent pane | `Ctrl+B z` |
| Zoom an outer tmux pane | `Ctrl+A z` |

Herdr uses its `Ctrl+B` prefix; tmux uses `Ctrl+A`. No Herdr-specific key
forwarding is needed. Unprefixed `Ctrl+h/j/k/l` and `Alt+,/./u/d` retain the
existing smart-splits behavior for Neovim and outer tmux panes. In the `agents`
window they act on outer tmux panes; they no longer reach Herdr or agent prompts.

If you loaded the earlier `Ctrl+A H` binding, run `tmux unbind-key -q H` once
after reloading the new config. Reloading tmux does not remove deleted bindings.

Use the default local Herdr session from both Neovim and the `agents` window.
Neovim runs directly in tmux; do not nest tmux inside Herdr or invent
`HERDR_ENV`, pane IDs, or workspace IDs. If you deliberately use a named Herdr
session, Neovim, Herdr, and the shell running Workmux must inherit the same
`HERDR_SESSION`. An inherited `HERDR_SOCKET_PATH` can override that choice.

## Open a worktree

Keep Herdr running in the central `agents` window. From the repository, create
the checkout and editor with Workmux:

```sh
workmux add feature-a
```

The global Workmux `post_create` hook opens that checkout as a Herdr workspace
before the Neovim window opens. It uses Workmux's resolved path and handle, so
custom names and worktree directories work too. `--no-focus` keeps Herdr's
current selection; choose the new workspace with `Ctrl+B w`. Change it to
`--focus` if you want Herdr to select each newly added workspace automatically.

If Herdr is stopped or the command fails, the hook prints a warning in the
terminal that ran Workmux and continues opening Neovim. Start Herdr, then run
this from the repository to open or recover the matching workspace:

```sh
herdr worktree open --cwd "$PWD" \
  --path "$(workmux path feature-a)" --label feature-a --focus
```

Start Claude, Codex, or another agent in that Herdr workspace. Multiple agents
share its checkout and editor. Give simultaneous independent implementations
different worktrees; use additional agents in the same checkout for review
or investigation.

`workmux open feature-a` reuses the editor window. Herdr also reuses an already
open checkout. Workmux's Worktrees dashboard remains useful; its Agents tab
does not track agents hosted inside Herdr. Do not install Workmux agent status
hooks for those agents.

Reopening an existing editor window skips the hook, even with
`workmux open --run-hooks`. Use the explicit Herdr command above if its
workspace was closed. Editor switching and Herdr workspace switching remain
independent. The hook only opens a workspace; start agents inside Herdr.

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

After choosing, select the `agents` tmux window with `Ctrl+A` and its window
number. The plugin focuses the chosen agent inside Herdr but does not switch
the outer tmux window. Review the draft, add instructions, and press Enter
there. The configured mappings do not submit.
Only stage while the target is idle at its prompt.

Reference mappings refuse unsaved, missing, and special buffers. Save first,
or use `<leader>as` for unsaved text. They also check for disk changes before
referencing: if the buffer refreshes, the send stops so you can review and
select again. References are relative to the source
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

The embedded Claude, Codex, and OpenCode Neovim plugins are removed. Conversations
and edit approvals now happen in Herdr. Diffview reviews changes already on
disk; it does not replace an agent's approval prompt before writing.

The tracked `home/.chezmoiremove.tmpl` removes their old deployed configuration
files on the next Chezmoi apply, including from a fresh checkout. It is separate
from the generated cleanup manifest. Restart Neovim after applying; `:Lazy clean`
can remove unused plugin downloads.

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

Tested with tmux 3.8, Neovim 0.12.6, Herdr 0.9.5, Workmux 0.1.276, Smug
0.3.19, and Chezmoi 2.65.0. The Neovim plugin is pinned at
`2e99ef05c52e1a8ee71b630612a0f8ac18a9638e`.
Recheck context routing and keyboard behavior before upgrading the bridge.

The global Workmux config provides the editor-only layout and Herdr creation
hook. A project's own `.workmux.yaml` can override them; this repository uses
the same layout and inherits the hook. Projects with their own `post_create`
list must include `- "<global>"` to keep the global hook.
Happier and automatic cross-tool workspace synchronization are not configured.

## Validation

Verified on 2026-10-18 in temporary directories with private tmux and Herdr
servers. Existing user sessions were not used for the experiments.

- `make test` in the Neovim source directory: 122 tests passed.
- `bun test scripts/reconcile-configs.test.ts scripts/agent-prompt-editor.test.ts`:
  42 tests passed.
- Chezmoi removed the three old agent plugin specs in temporary homes, including
  upgrades with existing persistent state, a fresh source checkout, and repeated
  applies. The generation hook handled duplicate removal entries and cleared
  them after migration. Unrelated plugin files survived.
  Linux, macOS, and Windows removal paths rendered correctly;
  the full rendered Neovim configuration started successfully on Linux.
- Workmux created two editor worktrees; repeated opens reused the windows.
  Closing an editor preserved its agents. Closing Herdr workspaces preceded
  checkout removal, and Workmux remained usable with Herdr stopped.
- The global creation hook opened the exact checkout with a custom handle,
  branch slash, and spaces in the repository path. With Herdr stopped, it
  printed a warning and still opened Neovim. Explicit Herdr opens recovered
  closed workspaces and reused existing ones.
- A real tmux client exercised numbered window selection, SessionX, smart-splits,
  and clean/dirty file refresh after focus. Herdr's `Ctrl+B v/h/l` worked with
  the ordinary TPM bindings and no Herdr-specific forwarding overrides.
  Reloading an existing server restored TPM's eight bindings; the documented
  one-time unbind removed the old `H` shortcut.
- Context reached the selected pane with Herdr focused on another worktree.
  Duplicate agent types, cancellation, one/zero agents, reference guards,
  UTF-8, control bytes, and oversized payloads were checked.
  Saved-file references refresh changed buffers and stop for reselection,
  including Visual mode; dirty buffers retain their unsaved edits.
- Lazy installed the shipped repository-and-commit spec. Its first visual send
  worked; concurrent editors kept distinct context files even when forced to
  generate identical filenames. Files remained readable after editor exit.
- A real Claude Code Opus 5.5 max terminal displayed both kinds of draft without
  submission. Other agent transports used synthetic terminal receivers in this
  implementation test; model execution and cache-read permissions were not tested.

Claude Code `claude-opus-5-5` with `--effort max` reviewed the design and diff.
Its reference, file-freshness, and focus-check feedback is included. The final
review found no blocking code defects and requested additional runtime checks,
covered above.

Sources: [Herdr CLI](https://herdr.dev/docs/cli-reference/),
[Herdr context plugin](https://github.com/makyinmars/herdr-context.nvim),
[Workmux configuration](https://workmux.raine.dev/guide/configuration/),
[Smug](https://github.com/ivaaaan/smug).
