# Smart splits

Normal mode uses `Ctrl-h/j/k/l` to move and `Alt-,/./u/d` to resize
left/right/up/down. Resizing defaults to three cells and accepts a count.
Neovim terminal buffers also map `Ctrl-h/j/k/l` for navigation.

## Routing

- Inside tmux, the tmux backend owns `@pane-is-vim`. TPM forwards keys to
  Neovim when that pane marker is set; otherwise it moves or resizes tmux panes.
  Neovim handles its own windows first, then hands edge movement to tmux.
- Outside tmux, the WezTerm backend owns `IS_NVIM` and sends `SMART_SPLITS_REQ`
  when Neovim reaches a window edge. The official WezTerm GUI plugin handles
  those requests and publishes the `SMART_SPLITS_WEZTERM` environment handshake.
- WezTerm's local bindings forward keys to Neovim or a foreground tmux process.
  For SSH/WSL panes, tmux's client-attach hook sets `IS_TMUX` even when attaching
  to an existing Neovim session. Bash refreshes the marker on each prompt,
  clearing it after detach or final-session exit. A tmux detach hook alone
  cannot guarantee cleanup when the server exits with its last session.
- With neither multiplexer detected, movement stays within Neovim.

Remote Neovim is used inside tmux. Direct Neovim over plain SSH is not configured:
the WezTerm backend requires both `WEZTERM_PANE` and `SMART_SPLITS_WEZTERM`, which
SSH does not forward by default. With tmux selected, navigation stays within
Neovim and tmux; it does not continue into outer WezTerm panes.

The tmux backend has priority. Keep smart-splits eagerly loaded so its marker
exists before the first keypress. Backends clear their Neovim markers on
suspend/exit and restore them on resume.

The GUI plugin loads before `config.keys`: its request handler and environment
handshake remain active, while local bindings preserve tmux routing and the
three-cell resize step. Edge navigation uses the existing `wrap` policy.

## Cause of the v3 regression

Core v3 removed bundled multiplexer integrations and automatic detection.
The old `setup({})` configured no backend. Live tmux bindings checked
`@pane-is-vim`, but every inspected Neovim pane had that marker unset, so
tmux consumed the navigation keys before Neovim received them.

WezTerm's routing also ignored `IS_TMUX`, intercepting navigation and resize
keys whenever a tab had multiple WezTerm panes. Adding only the Neovim WezTerm
backend would still be incomplete: its GUI companion is required as well.

## Activate and diagnose

After applying these dotfiles:

1. Reload WezTerm, then open a new pane so its environment includes the handshake.
2. Open Neovim and run `:Lazy install` to install the two backend plugins.
3. Reload tmux and press `Ctrl-a I` to install the new TPM `backend-tmux` plugin.
4. Reload tmux again and restart Neovim. Run `:checkhealth smart-splits`.

For an existing SSH/WSL connection, detach and reattach after reloading tmux so
the new client hook publishes its marker.

Inspect tmux with `tmux display-message -p '#{@pane-is-vim}'` from the
Neovim pane; it should report `1` while Neovim owns it. For WezTerm without tmux,
check `:lua print(vim.env.WEZTERM_PANE, vim.env.SMART_SPLITS_WEZTERM)`.

Upstream's WezTerm backend is currently marked unstable. Its two halves must
use compatible versions when updating.

## Verification

Reviewed against upstream documentation on 2026-10-14. Core `v3.0.0` is the latest
v3 release; the explicit backend list, eager loading, TPM plugin, and WezTerm GUI
companion follow the current installation guides. The WezTerm backend README
still shows the development `v3` branch; use core's released `^3.0.0` recommendation.

`make test` covers Neovim/backend calls and WezTerm key routing. `make test-tmux`
checks real client marker output, including attaching without a new shell prompt.
Real WezTerm GUI key dispatch still requires a local check after activation.

## Upstream documentation

- [Core v3 migration](https://github.com/smart-splits-nvim/smart-splits.nvim#migration-from-v2)
- [tmux installation and marker lifecycle](https://github.com/smart-splits-nvim/backend-tmux#installation)
- [WezTerm installation and request protocol](https://github.com/smart-splits-nvim/backend-wezterm#install)
- [WezTerm foreground process detection](https://wezterm.org/config/lua/pane/get_foreground_process_name.html)
- [tmux client hooks](https://man.openbsd.org/tmux#HOOKS)
