# Smart splits

In normal mode, use `Ctrl-h/j/k/l` to move between splits and `Alt-,/./u/d` to
resize left, right, up, or down. Resizing defaults to three cells and accepts a
count. Neovim terminal buffers also support `Ctrl-h/j/k/l` navigation.

## Setup

After applying these dotfiles:

1. Reload WezTerm and open a new pane. The new pane receives the GUI plugin's
   environment settings.
2. Open Neovim and run `:Lazy install` to install both backend plugins.
3. Reload tmux and press `Ctrl-a I` to install the new TPM `backend-tmux` plugin.
4. Reload tmux again and restart Neovim. Run `:checkhealth smart-splits`.

For an existing SSH/WSL connection, detach and reattach after reloading tmux.
This lets the new attach hook tell WezTerm that tmux is running.

Upstream marks the WezTerm backend as unstable. When updating, keep its Neovim
and GUI plugins on compatible versions.

## If keys do not work

- Inside tmux, run `tmux display-message -p '#{@pane-is-vim}'` from the Neovim
  pane. It should report `1` while Neovim is active.
- In WezTerm without tmux, check
  `:lua print(vim.env.WEZTERM_PANE, vim.env.SMART_SPLITS_WEZTERM)`.

## How keys reach the right pane

smart-splits chooses the tmux backend first. It loads at startup so tmux can
recognize Neovim before the first keypress.

- Inside tmux, the backend sets `@pane-is-vim`. TPM sends keys to Neovim while
  this marker is set; otherwise it moves or resizes tmux panes. Neovim handles
  its own windows first, then asks tmux to move when it reaches a window edge.
- In WezTerm without tmux, the backend sets `IS_NVIM`. At a Neovim window edge,
  it sends `SMART_SPLITS_REQ` to the official WezTerm GUI plugin. The GUI plugin
  handles the request and sets `SMART_SPLITS_WEZTERM` in the environment so
  Neovim can check that it is loaded.
- When neither multiplexer is detected, movement stays within Neovim.

WezTerm forwards keys to Neovim or a foreground tmux process. For SSH/WSL panes,
tmux's attach hook sets `IS_TMUX`, including when Neovim is already running.
Bash refreshes this marker at each prompt and clears it after detach or
final-session exit. A tmux detach hook alone can miss cleanup when the server
exits with its last session.

Both backends clear their Neovim markers when Neovim suspends or exits and
restore them when it resumes.

The GUI plugin loads before `config.keys`. Its request handler and environment
settings stay active while the local bindings handle tmux routing and resize
by three cells. Edge navigation uses `wrap`.

## Remote sessions

Use tmux for remote Neovim. Direct Neovim over plain SSH is not configured:
the WezTerm backend needs both `WEZTERM_PANE` and `SMART_SPLITS_WEZTERM`, which
SSH does not forward by default. With tmux selected, navigation stays within
Neovim and tmux; it does not continue into outer WezTerm panes.

## Why keys stopped working after v3

Core v3 removed bundled multiplexer integrations and automatic detection.
The old `setup({})` loaded no backend. tmux bindings checked `@pane-is-vim`,
which was unset in every Neovim pane inspected. tmux therefore handled the
navigation keys before Neovim received them.

WezTerm also ignored `IS_TMUX` and intercepted navigation and resize keys in
tabs with multiple WezTerm panes. WezTerm integration needs both the Neovim
backend and its GUI plugin.

## Versions and tests

The upstream documentation was checked on 2026-10-14, when `v3.0.0` was the
latest v3 release. Backend selection, startup loading, TPM setup, and the WezTerm
GUI plugin follow those installation guides. The WezTerm backend README still
shows the development `v3` branch; this config uses core's recommended `^3.0.0`.

`make test` covers Neovim calls to the backends and WezTerm key routing.
`make test-tmux` checks the markers a real tmux client sends, including when
attaching without a new shell prompt. Check key handling in the actual WezTerm
GUI after setup; that still needs local verification.

## Upstream documentation

- [Core v3 migration](https://github.com/smart-splits-nvim/smart-splits.nvim#migration-from-v2)
- [tmux installation and marker lifecycle](https://github.com/smart-splits-nvim/backend-tmux#installation)
- [WezTerm installation and request protocol](https://github.com/smart-splits-nvim/backend-wezterm#install)
- [WezTerm foreground process detection](https://wezterm.org/config/lua/pane/get_foreground_process_name.html)
- [tmux client hooks](https://man.openbsd.org/tmux#HOOKS)
