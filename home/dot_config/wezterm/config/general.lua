---@type ConfigModule
return {
  apply_to_config = function(config)
    config.scrollback_lines = 10000

    -- Agent notification support
    -- Show OSC 777/OSC 9 toast notifications from all panes (including unfocused)
    config.notification_handling = 'AlwaysShow'

    -- Audible bell: play system sound on BEL (\a) from agents
    config.audible_bell = 'SystemBeep'
  end,
}
