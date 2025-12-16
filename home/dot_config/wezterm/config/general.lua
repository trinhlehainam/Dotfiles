---@type ConfigModule
return {
  apply_to_config = function(config)
    config.front_end = 'WebGpu'
    config.webgpu_power_preference = 'HighPerformance'
    config.max_fps = 120
    config.animation_fps = 60
    config.scrollback_lines = 10000
  end,
}
