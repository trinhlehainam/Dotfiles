local platform = require('utils.platform')

---@type Config
local config = {
  use_fancy_tab_bar = false,
  hide_tab_bar_if_only_one_tab = false,
  tab_max_width = 25,

  window_padding = {
    left = 8,
    right = 8,
    top = 8,
    bottom = 8,
  },

  initial_cols = 120,
  initial_rows = 30,
}

if platform.is_win then
  config.win32_system_backdrop = 'Disable'
  config.window_background_opacity = 0.6
  config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
  config.integrated_title_button_style = 'Windows'
end

return config
