local wezterm = require('wezterm')

return {
  apply = function(config)
    local smart_splits = wezterm.plugin.require('https://github.com/mrjones2014/smart-splits.nvim')

    smart_splits.apply_to_config(config, {
      direction_keys = {
        move = { 'h', 'j', 'k', 'l' },
        resize = { ',', 'd', 'u', '.' },
      },
      modifiers = {
        move = 'CTRL',
        resize = 'META',
      },
      log_level = 'info',
    })
  end,
}
