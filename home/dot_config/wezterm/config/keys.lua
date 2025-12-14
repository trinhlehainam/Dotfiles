local wezterm = require('wezterm')
local platform = require('utils.platform')

local act = wezterm.action

local copy_destination = platform.is_linux and 'ClipboardAndPrimarySelection' or 'Clipboard'

return {
  leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 },
  keys = {
    { key = 'C', mods = 'CTRL|SHIFT', action = act.CopyTo(copy_destination) },
    { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom('Clipboard') },

    {
      key = 'l',
      mods = 'ALT',
      action = act.ShowLauncherArgs({ flags = 'FUZZY|LAUNCH_MENU_ITEMS|DOMAINS|WORKSPACES' }),
    },

    { key = 't', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },

    { key = '-', mods = 'LEADER', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
    { key = '|', mods = 'LEADER', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
    { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
    { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane({ confirm = true }) },

    { key = 'c', mods = 'LEADER', action = act.SpawnTab('CurrentPaneDomain') },
    { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
    { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },

    { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },

    { key = 's', mods = 'LEADER', action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }) },
  },
}
