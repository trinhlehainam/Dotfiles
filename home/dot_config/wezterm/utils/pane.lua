local M = {}

---@param pane Pane
function M.is_nvim(pane)
  local user_vars = pane:get_user_vars()
  return user_vars and user_vars.IS_NVIM == 'true'
end

---@param pane Pane
function M.is_tmux(pane)
  -- Local process detection works with any shell and ignores stale markers after detach.
  -- https://wezterm.org/config/lua/pane/get_foreground_process_name.html
  local process = pane:get_foreground_process_name()
  if process then
    local name = process:gsub('.*[/\\]', ''):gsub('%.exe$', ''):lower()
    -- SSH/WSL expose the transport process, so use the remote shell's marker.
    if name ~= 'ssh' and name ~= 'wsl' and name ~= 'wslhost' then
      return name == 'tmux'
    end
  end

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
