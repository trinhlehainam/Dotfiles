---@type ConfigModule
return {
  apply_to_config = function(config)
    config.scrollback_lines = 10000

    -- Show terminal notifications regardless of window focus.
    config.notification_handling = 'AlwaysShow'

    -- Play system sound for terminal bells.
    config.audible_bell = 'SystemBeep'
  end,
}
