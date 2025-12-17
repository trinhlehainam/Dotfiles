# WezTerm configuration

A small, modular WezTerm config written in Lua.

- Entry point: `wezterm.lua`
- Config fragments: `config/*.lua` (each exports `apply_to_config(config)`)
- Event handlers: `events/*.lua`
- Helper modules: `utils/*.lua`

## References / inspiration

This configuration borrows ideas and small implementation details from:

- https://github.com/KevinSilvester/wezterm-config
- https://github.com/mrjones2014/smart-splits.nvim (concept for “smart” pane navigation/resizing)
- https://github.com/pasanec/wezterm_win/blob/main/wezterm.lua (silent executable detection patterns)
- https://github.com/wezterm/wezterm/issues/5963#issuecomment-2533250740 (background process checks)
