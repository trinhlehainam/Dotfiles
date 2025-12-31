---Wallpaper keybinding configuration.
---
---Registers CTRL+SHIFT+B to open the wallpaper picker.
---@type ConfigModule

local wezterm = require('wezterm') ---@type Wezterm
local wallpaper = require('utils.wallpaper')

return {
  apply_to_config = function(config)
    config.keys = config.keys or {}
    table.insert(config.keys, {
      key = 'B',
      mods = 'CTRL|SHIFT',
      action = wezterm.action_callback(function(window, pane)
        wallpaper.show_picker(window, pane)
      end),
    })
  end,
}
