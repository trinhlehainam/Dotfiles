# WezTerm configuration

A small, modular WezTerm config written in Lua.

## Smart splits

Use `Ctrl-h/j/k/l` to navigate and `Alt-,/./u/d` to resize. The official
smart-splits v3 GUI plugin handles requests from Neovim. When tmux is running,
WezTerm forwards these keys to it, checking the local process or the remote
`IS_TMUX` marker. See the
[routing and setup guide](../../.shared-configs/nvim/doc/smart-splits.md).

## Clipboard shortcuts

- `Ctrl+Shift+V`: paste text directly, without launching PowerShell or WSL commands.
- `Ctrl+Shift+I`: in Windows WezTerm with a WSL pane, save the clipboard image as a PNG
  under `/tmp/wezterm-smart-paste/` and insert its `@path`. If no image can be saved,
  nothing is inserted.

## References / inspiration

This configuration borrows ideas and small implementation details from:

- https://github.com/KevinSilvester/wezterm-config
- https://github.com/mrjones2014/smart-splits.nvim (concept for “smart” pane navigation/resizing)
- https://github.com/pasanec/wezterm_win/blob/main/wezterm.lua (silent executable detection patterns)
- https://github.com/wezterm/wezterm/issues/5963#issuecomment-2533250740 (background process checks)
