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

-------------------------------------------------------------------------------
-- CSI u Escape Sequences
-------------------------------------------------------------------------------
-- Format: ESC [ <keycode> ; <modifier> u
-- Modifiers: 2=Shift, 5=Ctrl, 6=Ctrl+Shift
-- Reference: https://sw.kovidgoyal.net/kitty/keyboard-protocol/
-------------------------------------------------------------------------------
local CSI_U_ENTER = {
  SHIFT = '\x1b[13;2u',
  CTRL = '\x1b[13;5u',
  ['CTRL|SHIFT'] = '\x1b[13;6u',
}

-------------------------------------------------------------------------------
-- Conditional Action Helper
-------------------------------------------------------------------------------

---Dispatch action based on pane predicate.
---@param predicate fun(pane: Pane): boolean
---@param on_true Action
---@param on_false Action
---@return Action
local function when(predicate, on_true, on_false)
  return wezterm.action_callback(function(win, p)
    win:perform_action(predicate(p) and on_true or on_false, p)
  end)
end

---Modifier+Enter binding: CSI u sequence in tmux, normal key otherwise.
---@param mods 'SHIFT'|'CTRL'|'CTRL|SHIFT'
---@return Key
local function tmux_mods_enter(mods)
  return {
    key = 'Enter',
    mods = mods,
    action = when(
      pane.is_tmux,
      act.SendString(CSI_U_ENTER[mods]),
      act.SendKey({ key = 'Enter', mods = mods })
    ),
  }
end

--- @type MouseBindingBase[]
local mouse_bindings = {
  -- Ctrl-click will open the link under the mouse cursor
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor,
  },
}

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
        { key = '\\', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
        { key = 'c', action = act.SpawnTab('CurrentPaneDomain') },
        { key = 'n', action = act.ActivateTabRelative(1) },
        { key = 'p', action = act.ActivateTabRelative(-1) },
        { key = '[', action = act.ActivateCopyMode },
        { key = 's', action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }) },
      },
    }

    config.keys = {
      -- misc/useful
      { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
      { key = 'F4', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },
      {
        key = 'F5',
        mods = 'NONE',
        action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
      },
      { key = 'F11', mods = 'NONE', action = act.ToggleFullScreen },

      { key = 'C', mods = 'CTRL|SHIFT', action = act.CopyTo(copy_destination) },
      { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom('Clipboard') },

      -- Modifier+Enter: CSI u in tmux, normal key otherwise
      tmux_mods_enter('SHIFT'),
      tmux_mods_enter('CTRL'),
      tmux_mods_enter('CTRL|SHIFT'),

      -- Ctrl+a: passthrough in tmux, activate key-table otherwise
      {
        key = 'a',
        mods = 'CTRL',
        action = when(
          pane.is_tmux,
          act.SendKey({ key = 'a', mods = 'CTRL' }),
          act.ActivateKeyTable({ name = 'tmux', one_shot = true, timeout_milliseconds = 1000 })
        ),
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

    config.mouse_bindings = mouse_bindings
  end,
}
