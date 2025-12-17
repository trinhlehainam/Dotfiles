local M = {}

---@param pane Pane
function M.is_nvim(pane)
  local user_vars = pane:get_user_vars()
  return user_vars and user_vars.IS_NVIM == 'true'
end

---@param pane Pane
function M.is_tmux(pane)
  local user_vars = pane:get_user_vars()
  return user_vars and user_vars.IS_TMUX == 'true'
end

---@param win Window
---@return number
function M.pane_count(win)
  local tab = win:active_tab()
  return tab and #tab:panes() or 1
end

return M
