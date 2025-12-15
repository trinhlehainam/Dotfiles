local wezterm = require('wezterm') ---@type Wezterm

local strings = require('utils.strings')

local M = {}

M.direction_flag = {
  Left = '-L',
  Down = '-D',
  Up = '-U',
  Right = '-R',
}

M.edge_format = {
  Left = '#{pane_at_left}',
  Down = '#{pane_at_bottom}',
  Up = '#{pane_at_top}',
  Right = '#{pane_at_right}',
}

function M.run(args)
  local ok, stdout, stderr = wezterm.run_child_process({ 'tmux', table.unpack(args) })
  if not ok then
    wezterm.log_info('tmux command failed: ', { args = args, stderr = stderr })
    return nil
  end

  return strings.trim_right(stdout or '')
end

function M.get_pane_id(pane)
  local tty = pane:get_tty_name()
  if not tty then
    return nil
  end

  local stdout = M.run({ 'list-panes', '-a', '-F', '#{pane_id} #{pane_tty}' })
  if not stdout or stdout == '' then
    return nil
  end

  for line in stdout:gmatch('[^\r\n]+') do
    local pane_id, pane_tty = line:match('^(%S+)%s+(%S+)$')
    if pane_tty == tty then
      return pane_id
    end
  end

  return nil
end

function M.window_panes(pane_id)
  local stdout = M.run({ 'display-message', '-p', '-t', pane_id, '#{window_panes}' })
  return tonumber(stdout or '')
end

function M.at_edge(pane_id, direction)
  local stdout = M.run({ 'display-message', '-p', '-t', pane_id, M.edge_format[direction] })
  return stdout == '1'
end

function M.select_pane(pane_id, direction)
  return M.run({ 'select-pane', '-t', pane_id, M.direction_flag[direction] })
end

function M.resize_pane(pane_id, direction, amount)
  return M.run({ 'resize-pane', '-t', pane_id, M.direction_flag[direction], tostring(amount) })
end

return M
