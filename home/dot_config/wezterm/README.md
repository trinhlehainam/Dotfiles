# WezTerm configuration

A small, modular WezTerm config written in Lua.

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
