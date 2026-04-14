---@type ConfigModule
return {
  apply_to_config = function(config)
    config.scrollback_lines = 10000

    -- Agent notification support
    -- Suppress OSC 777 toasts from the focused pane to avoid duplicating the
    -- OSC 1337-based toast emitted by events/agent_notify.lua
    config.notification_handling = 'SuppressFromFocusedPane'

    -- Audible bell: play system sound on BEL (\a) from agents
    config.audible_bell = 'SystemBeep'
  end,
}
