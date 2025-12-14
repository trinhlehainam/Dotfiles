local wezterm = require('wezterm')
-- https://github.com/mrjones2014/smart-splits.nvim?tab=readme-ov-file#wezterm
local smart_splits = wezterm.plugin.require('https://github.com/mrjones2014/smart-splits.nvim')
local config = wezterm.config_builder()
-- you can put the rest of your Wezterm config here
smart_splits.apply_to_config(config, {
  direction_keys = {
    move = { 'h', 'j', 'k', 'l' },
    resize = { ',', 'd', 'u', '.' },
  },
  -- modifier keys to combine with direction_keys
  modifiers = {
    move = 'CTRL', -- modifier to use for pane movement, e.g. CTRL+h to move left
    resize = 'META', -- modifier to use for pane resize, e.g. META+h to resize to the left
  },
  -- log level to use: info, warn, error
  log_level = 'info',
})
return config
