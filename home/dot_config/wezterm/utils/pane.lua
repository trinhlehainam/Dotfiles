local M = {}

function M.is_vim(pane)
  local user_vars = pane:get_user_vars()
  return user_vars and user_vars.IS_NVIM == 'true'
end

function M.is_tmux(pane)
  local process_name = pane:get_foreground_process_name() or ''
  return process_name:match('tmux') ~= nil
end

return M
