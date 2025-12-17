local wezterm = require('wezterm')

local pane = require('utils.pane')

---Helpers for "smart" pane navigation/resizing.
---
---When the active pane is running Neovim (or when there is only a single pane),
---the key binding is forwarded into the application instead of being handled by
---WezTerm. This enables Neovim-side plugins/mappings to implement split
---navigation and resizing with the same key chords.
---
---This approach is inspired by (and conceptually similar to) smart-splits.nvim:
---https://github.com/mrjones2014/smart-splits.nvim
---
---Usage (example):
---
---```lua
---local nav = require('utils.navigation')
---return {
---  -- Navigate between WezTerm panes, unless Neovim wants it.
---  nav.move('h', 'Left'),
---  nav.move('j', 'Down'),
---  nav.move('k', 'Up'),
---  nav.move('l', 'Right'),
---
---  -- Resize panes, unless Neovim wants it.
---  nav.resize('h', 'Left', { mods = 'META', amount = 3 }),
---}
---```
local M = {}

local function should_passthrough(win, current_pane)
  return pane.is_nvim(current_pane) or pane.pane_count(win) == 1
end

function M.move(key, direction, opts)
  local options = opts or {}
  local mods = options.mods or 'CTRL'

  local act = wezterm.action ---@type Action

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

function M.resize(key, direction, opts)
  local options = opts or {}
  local mods = options.mods or 'META'
  local amount = options.amount or 3

  local act = wezterm.action ---@type Action

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
