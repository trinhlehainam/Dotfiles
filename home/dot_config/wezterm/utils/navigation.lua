local wezterm = require('wezterm')

local pane = require('utils.pane')

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
