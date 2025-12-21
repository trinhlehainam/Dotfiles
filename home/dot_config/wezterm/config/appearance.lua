local platform = require('utils.platform')

---@type ConfigModule
return {
  apply_to_config = function(config)
    config.max_fps = 120
    config.front_end = 'WebGpu'
    config.webgpu_power_preference = 'HighPerformance'

    -- cursor
    config.animation_fps = 120

    -- color scheme
    config.color_scheme = 'Catppuccin Mocha'

    -- tab bar
    config.use_fancy_tab_bar = false
    config.hide_tab_bar_if_only_one_tab = false
    config.tab_max_width = 25

    -- window
    config.window_padding = {
      left = 8,
      right = 8,
      top = 8,
      bottom = 8,
    }

    if platform.is_win then
      config.win32_system_backdrop = 'Disable'
      config.window_background_opacity = 0.6
      config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
      config.integrated_title_button_style = 'Windows'
    end
  end,
}
