local wezterm = require('wezterm') ---@type Wezterm

local platform = require('utils.platform')

local M = {}

---@type table<string, boolean>
local cache = {}

---@param executable string
---@return boolean
function M.exists(executable)
  if cache[executable] ~= nil then
    return cache[executable]
  end

  local args
  if platform.is_win then
    args = { 'where.exe', '/Q', executable }
  else
    args = { 'sh', '-c', string.format('command -v %q >/dev/null 2>&1', executable) }
  end

  local ok, success = pcall(wezterm.run_child_process, args)
  local exists = ok and success == true

  cache[executable] = exists
  return exists
end

---@param executables string[]
---@return string|nil
function M.first(executables)
  for _, executable in ipairs(executables) do
    if M.exists(executable) then
      return executable
    end
  end

  return nil
end

return M
