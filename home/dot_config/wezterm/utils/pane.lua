local M = {}

function M.is_vim(pane)
  local user_vars = pane:get_user_vars()
  return user_vars and user_vars.IS_NVIM == 'true'
end

---@param pane Pane
function M.is_tmux(pane)
  local user_vars = pane:get_user_vars()
  return user_vars and user_vars.IS_TMUX == 'true'
end

return M
