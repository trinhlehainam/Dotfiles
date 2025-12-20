local wezterm = require('wezterm') --- @type Wezterm

local pane = require('utils.pane')

---Keybinding factories for "smart" pane navigation/resizing.
---
---The goal is to use a single set of key chords for both:
---
---- WezTerm pane navigation/resizing when the active tab has multiple panes, and
---- in-app split navigation/resizing (typically Neovim) when the active pane is
---   that app.
---
---In other words: if the current pane is running Neovim (or if there is only a
---single WezTerm pane in the active tab), we *passthrough* the key press to the
---application via `SendKey`. Otherwise, we let WezTerm handle it via
---`ActivatePaneDirection` / `AdjustPaneSize`.
---
---This approach is inspired by (and conceptually similar to) smart-splits.nvim:
---https://github.com/mrjones2014/smart-splits.nvim
---
---Integration requirements
---
---Neovim detection is based on a user var (`IS_NVIM`) set on the pane.
---`utils.pane.is_nvim()` checks:
---
---```lua
---pane:get_user_vars().IS_NVIM == 'true'
---```
---
---So you must set/unset that variable from inside Neovim.
---WezTerm supports setting user vars via the iTerm2-compatible escape sequence:
---
---`OSC 1337 ; SetUserVar=<KEY>=<BASE64(VALUE)> BEL`
---
---A minimal Neovim snippet (put in your config, or adapt to an autocmd):
---
---```lua
---local function wezterm_set_user_var(key, value)
---  local b64 = vim.base64.encode(value)
---  vim.fn.chansend(vim.v.stderr, string.format('\x1b]1337;SetUserVar=%s=%s\x07', key, b64))
---end
---
---wezterm_set_user_var('IS_NVIM', 'true')
---```
---
---Usage
---
---`move()` and `resize()` return WezTerm `KeyBinding` tables; include them in
---`config.keys`.
---
---```lua
---local nav = require('utils.navigation')
---
---config.keys = {
---  -- Navigate between WezTerm panes, unless Neovim wants it.
---  nav.move('h', 'Left'),
---  nav.move('j', 'Down'),
---  nav.move('k', 'Up'),
---  nav.move('l', 'Right'),
---
---  -- Resize panes, unless Neovim wants it.
---  nav.resize(',', 'Left'),
---  nav.resize('d', 'Down'),
---  nav.resize('u', 'Up'),
---  nav.resize('.', 'Right'),
---}
---```
local M = {}

local function should_passthrough(win, current_pane)
  return pane.is_nvim(current_pane) or pane.pane_count(win) == 1
end

---@alias NavigationDirection 'Left' | 'Right' | 'Up' | 'Down'

---@class NavigationMoveOpts
---@field mods? string Modifier string for the binding (default: `'CTRL'`).
---
---Create a keybinding that either:
---- sends the key to the application (Neovim / single-pane tab), or
---- activates the adjacent WezTerm pane.
---
---@param key string Key (e.g. `'h'`).
---@param direction NavigationDirection Direction to move/activate.
---@param opts? NavigationMoveOpts Optional overrides.
---@return KeyBinding
function M.move(key, direction, opts)
  local options = opts or {}
  local mods = options.mods or 'CTRL'

  local act = wezterm.action ---@type Action

  ---@type KeyBinding
  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, current_pane)
      if should_passthrough(win, current_pane) then
        win:perform_action(act.SendKey({ key = key, mods = mods }), current_pane)
        return
      end

      win:perform_action(act.ActivatePaneDirection(direction), current_pane)
    end),
  }
end

---@class NavigationResizeOpts
---@field mods? string Modifier string for the binding (default: `'META'`).
---@field amount? integer Number of cells to resize by (default: `3`).
---
---Create a keybinding that either:
---- sends the key to the application (Neovim / single-pane tab), or
---- resizes the active WezTerm pane.
---
---@param key string Key (e.g. `','`).
---@param direction NavigationDirection Direction to resize toward.
---@param opts? NavigationResizeOpts Optional overrides.
---@return KeyBinding
function M.resize(key, direction, opts)
  local options = opts or {}
  local mods = options.mods or 'META'
  local amount = options.amount or 3

  local act = wezterm.action ---@type Action

  ---@type KeyBinding
  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, current_pane)
      if should_passthrough(win, current_pane) then
        win:perform_action(act.SendKey({ key = key, mods = mods }), current_pane)
        return
      end

      win:perform_action(act.AdjustPaneSize({ direction, amount }), current_pane)
    end),
  }
end

return M
