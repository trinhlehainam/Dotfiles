---Utility helpers to safely detect executables in PATH.
---
---Why this exists:
--- - Some configs want to dynamically build `launch_menu` entries (or keybindings)
---   based on which shells/tools are actually installed.
--- - Avoids `os.execute(...)` checks on Windows which can spawn visible shell
---   windows and slow down startup when used repeatedly.
---
---Implementation notes:
--- - Uses `wezterm.run_child_process` so checks are silent/non-interactive.
--- - Caches results per executable name to avoid repeating process spawns.
---
---References:
--- - https://github.com/pasanec/wezterm_win/blob/main/wezterm.lua
--- - https://github.com/wezterm/wezterm/issues/5963#issuecomment-2533250740
---
local wezterm = require('wezterm') ---@type Wezterm

local platform = require('utils.platform')

local M = {}

---@type table<string, boolean>
local cache = {}

---Checks whether `executable` can be resolved from `PATH`.
---
---On Windows, uses `where.exe /Q`.
---On non-Windows, uses `sh -c "command -v ..."`.
---
---Result is cached for the lifetime of the config Lua state.
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
