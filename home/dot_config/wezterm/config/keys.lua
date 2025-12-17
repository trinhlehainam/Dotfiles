local wezterm = require('wezterm') ---@type Wezterm
local platform = require('utils.platform')
local navigation = require('utils.navigation')

local act = wezterm.action ---@type Action

local copy_destination = platform.is_linux and 'ClipboardAndPrimarySelection' or 'Clipboard'

--- @type ConfigModule
return {
  apply_to_config = function(config)
    config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
    config.keys = {
      { key = 'C', mods = 'CTRL|SHIFT', action = act.CopyTo(copy_destination) },
      { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom('Clipboard') },

      navigation.move('h', 'Left'),
      navigation.move('j', 'Down'),
      navigation.move('k', 'Up'),
      navigation.move('l', 'Right'),

      navigation.resize(',', 'Left'),
      navigation.resize('d', 'Down'),
      navigation.resize('u', 'Up'),
      navigation.resize('.', 'Right'),

      {
        key = 'l',
        mods = 'ALT',
        action = act.ShowLauncherArgs({ flags = 'FUZZY|LAUNCH_MENU_ITEMS|DOMAINS|WORKSPACES' }),
      },

      { key = 't', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },

      { key = '-', mods = 'LEADER', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
      {
        key = '|',
        mods = 'LEADER',
        action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
      },
      { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
      { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane({ confirm = true }) },

      { key = 'c', mods = 'LEADER', action = act.SpawnTab('CurrentPaneDomain') },
      { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
      { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },

      { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },

      { key = 's', mods = 'LEADER', action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }) },
    }
  end,
}
