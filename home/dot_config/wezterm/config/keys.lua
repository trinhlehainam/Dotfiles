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
-- CSI u escape sequences
-------------------------------------------------------------------------------
-- `\x1b` is ESC (0x1b). It starts terminal escape sequences.
--
-- CSI u format:
--   ESC [ <keycode> ; <modifier> u
--
-- Example (Ctrl+Enter):
--   '\x1b[13;5u'   -- 13=Enter, 5=Ctrl
--
-- Refs:
-- - https://wezterm.org/config/lua/keyassignment/SendString.html
-- - https://sw.kovidgoyal.net/kitty/keyboard-protocol/
-- - https://github.com/sst/opencode/issues/1505#issuecomment-3411334883
-------------------------------------------------------------------------------
local CSI_U = {
  SHIFT = '\x1b[13;2u',
  CTRL = '\x1b[13;5u',
  ['CTRL|SHIFT'] = '\x1b[13;6u',
}

-------------------------------------------------------------------------------
-- Conditional Action Helper
-------------------------------------------------------------------------------

---Dispatch action based on a pane predicate.
---@param predicate fun(pane: Pane): boolean
---@param on_true ActionClass|ActionFuncClass
---@param on_false ActionClass|ActionFuncClass
---@return Action
local function when(predicate, on_true, on_false)
  return wezterm.action_callback(function(win, current_pane)
    win:perform_action(predicate(current_pane) and on_true or on_false, current_pane)
  end)
end

---@alias EnterMods 'SHIFT'|'CTRL'|'CTRL|SHIFT'

---Modifier+Enter binding.
---
---In tmux: send CSI u so TUIs can distinguish modifier+Enter.
---Outside tmux: send the normal key event.
---@param mods EnterMods
---@return Key
local function tmux_mod_enter(mods)
  local tmux_sequence = assert(CSI_U[mods], 'Missing CSI u sequence for mods: ' .. mods)

  return {
    key = 'Enter',
    mods = mods,
    action = when(
      pane.is_tmux,
      act.SendString(tmux_sequence),
      act.SendKey({ key = 'Enter', mods = mods })
    ),
  }
end

--- @source https://wezterm.org/config/lua/keyassignment/OpenLinkAtMouseCursor.html#openlinkatmousecursor
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
      tmux_mod_enter('SHIFT'),
      tmux_mod_enter('CTRL'),
      tmux_mod_enter('CTRL|SHIFT'),

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
