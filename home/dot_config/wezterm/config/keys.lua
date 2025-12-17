local wezterm = require('wezterm') ---@type Wezterm
local platform = require('utils.platform')
local pane = require('utils.pane')
local navigation = require('utils.navigation')

local act = wezterm.action ---@type Action

---Destination for `CopyTo()` bindings.
---
---On Linux, prefer copying to both the clipboard and the X11 primary selection
---(middle-click paste). On other platforms, fall back to the regular clipboard.
local copy_destination = platform.is_linux and 'ClipboardAndPrimarySelection' or 'Clipboard'

---WezTerm config module that installs key-tables and key bindings.
---
---Notable behaviors:
---- `CTRL-a` acts like a tmux prefix (passthrough to tmux if detected,
---   otherwise activates the local `tmux` key-table).
---- Smart pane navigation/resizing comes from `utils.navigation`.
--- @type ConfigModule
return {
  apply_to_config = function(config)
    --- https://wezterm.org/config/key-tables.html
    config.key_tables = {
      tmux = {
        { key = '-', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
        { key = '|', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
        { key = 'c', action = act.SpawnTab('CurrentPaneDomain') },
        { key = 'n', action = act.ActivateTabRelative(1) },
        { key = 'p', action = act.ActivateTabRelative(-1) },
        { key = '[', action = act.ActivateCopyMode },
        { key = 's', action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }) },
      },
    }

    config.keys = {
      { key = 'C', mods = 'CTRL|SHIFT', action = act.CopyTo(copy_destination) },
      { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom('Clipboard') },

      {
        key = 'a',
        mods = 'CTRL',
        action = wezterm.action_callback(function(win, current_pane)
          if pane.is_tmux(current_pane) then
            win:perform_action(act.SendKey({ key = 'a', mods = 'CTRL' }), current_pane)
            return
          end

          win:perform_action(
            act.ActivateKeyTable({ name = 'tmux', one_shot = true, timeout_milliseconds = 1000 }),
            current_pane
          )
        end),
      },

      navigation.move('h', 'Left'),
      navigation.move('j', 'Down'),
      navigation.move('k', 'Up'),
      navigation.move('l', 'Right'),

      navigation.resize(',', 'Left'),
      navigation.resize('d', 'Down'),
      navigation.resize('u', 'Up'),
      navigation.resize('.', 'Right'),
    }
  end,
}
