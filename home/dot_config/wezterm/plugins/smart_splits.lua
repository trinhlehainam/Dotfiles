local wezterm = require('wezterm') ---@type Wezterm
local smart_splits = wezterm.plugin.require('https://github.com/smart-splits-nvim/backend-wezterm')

-- https://github.com/smart-splits-nvim/backend-wezterm#install
---@type ConfigModule
return {
  apply_to_config = function(config)
    smart_splits.apply_to_config(config, { at_edge = 'wrap' })
  end,
}
