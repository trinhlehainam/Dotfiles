local wezterm = require('wezterm')

local pane = require('utils.pane')

local M = {}

local function pane_count(win)
  local tab = win:active_tab()
  return tab and #tab:panes() or 1
end

function M.tmux(key, opts)
  local options = opts or {}
  local prefix = options.tmux_prefix or { key = 'a', mods = 'CTRL' }
  local mods = options.tmux_key_mods or ''

  local act = wezterm.action ---@type Action
  return act.Multiple({
    act.SendKey({ key = prefix.key, mods = prefix.mods }),
    act.SendKey({ key = key, mods = mods }),
  })
end

local function should_send_to_app(win, current_pane)
  return pane.is_vim(current_pane) or pane_count(win) == 1
end

function M.move(key, direction, opts)
  local options = opts or {}
  local mods = options.mods or 'CTRL'
  local send_mods = options.send_mods or mods
  local tmux_key = options.tmux_key or key

  local act = wezterm.action ---@type Action

  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, current_pane)
      if pane.is_tmux(current_pane) then
        win:perform_action(M.tmux(tmux_key, options), current_pane)
        return
      end

      if should_send_to_app(win, current_pane) then
        win:perform_action(act.SendKey({ key = key, mods = send_mods }), current_pane)
        return
      end

      win:perform_action(act.ActivatePaneDirection(direction), current_pane)
    end),
  }
end

function M.resize(key, direction, opts)
  local options = opts or {}
  local mods = options.mods or 'META'
  local send_mods = options.send_mods or mods
  local amount = options.default_resize_amount or 3
  local tmux_key = options.tmux_key or key

  local act = wezterm.action ---@type Action

  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, current_pane)
      if pane.is_tmux(current_pane) then
        win:perform_action(M.tmux(tmux_key, options), current_pane)
        return
      end

      if should_send_to_app(win, current_pane) then
        win:perform_action(act.SendKey({ key = key, mods = send_mods }), current_pane)
        return
      end

      win:perform_action(act.AdjustPaneSize({ direction, amount }), current_pane)
    end),
  }
end

return M
