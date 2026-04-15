---@type ConfigModule
return {
  apply_to_config = function(config)
    config.scrollback_lines = 10000

    -- Agent notifications primarily use SetUserVar -> user-var-changed ->
    -- toast_notification(). Keep AlwaysShow so any non-AGENT_NOTIFY terminal
    -- notification fallback still surfaces regardless of focus.
    config.notification_handling = 'AlwaysShow'

    -- Play system sound for BEL-only fallback terminals.
    config.audible_bell = 'SystemBeep'
  end,
}
