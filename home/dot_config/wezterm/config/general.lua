---@type ConfigModule
return {
  apply_to_config = function(config)
    config.scrollback_lines = 10000
    config.enable_kitty_keyboard = true
  end,
}
