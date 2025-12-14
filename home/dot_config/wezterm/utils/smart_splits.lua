local wezterm = require('wezterm')

local pane_utils = require('utils.pane')
local tmux = require('utils.tmux')

local M = {}

function M.nav(resize_or_move, key, direction, opts)
  local options = opts or {}
  local mods = options.mods or (resize_or_move == 'resize' and 'META' or 'CTRL')
  local default_resize_amount = options.default_resize_amount or 3

  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, pane)
      local wezterm_panes = #win:active_tab():panes()
      if pane_utils.is_vim(pane) or wezterm_panes == 1 then
        win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
        return
      end

      if pane_utils.is_tmux(pane) then
        local pane_id = tmux.get_pane_id(pane)
        if pane_id then
          local window_panes = tmux.window_panes(pane_id) or 1
          if window_panes > 1 then
            if resize_or_move == 'move' then
              if not tmux.at_edge(pane_id, direction) then
                tmux.select_pane(pane_id, direction)
                return
              end
            else
              tmux.resize_pane(pane_id, direction, default_resize_amount)
              return
            end
          end
        end
      end

      if resize_or_move == 'resize' then
        win:perform_action({ AdjustPaneSize = { direction, default_resize_amount } }, pane)
      else
        win:perform_action({ ActivatePaneDirection = direction }, pane)
      end
    end),
  }
end

return M
