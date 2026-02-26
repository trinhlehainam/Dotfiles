local wezterm = require('wezterm') ---@type Wezterm

local platform = require('utils.platform')
local strings = require('utils.strings')

local M = {}

---@type WslDomain[]|nil
local cached_domains = nil

---@type string|nil
local preferred = nil

---@type table<string, string>
local cached_windows_paths = {}

---@param wsl_distro string
---@param linux_path string
---@return string
local function windows_path_cache_key(wsl_distro, linux_path)
  return string.format('%s\0%s', wsl_distro, linux_path)
end

---@param domain_name string
---@return string|nil
function M.distro_from_domain_name(domain_name)
  local distro = domain_name:match('^WSL:(.+)$')
  if not distro then
    return nil
  end

  distro = strings.trim(distro)
  if distro == '' then
    return nil
  end

  return distro
end

---@param pane Pane
---@return string|nil
function M.pane_domain_name(pane)
  local ok, domain_name = pcall(function()
    return pane:get_domain_name()
  end)

  if not ok or type(domain_name) ~= 'string' or domain_name == '' then
    return nil
  end

  return domain_name
end

---@param pane Pane
---@return string|nil
function M.pane_distro(pane)
  local domain_name = M.pane_domain_name(pane)
  if not domain_name then
    return nil
  end

  return M.distro_from_domain_name(domain_name)
end

---@param wsl_distro string
---@param args string[]
---@return boolean,string|nil
local function run_wsl_command(wsl_distro, args)
  local command = {
    'wsl.exe',
    '-d',
    wsl_distro,
    '--',
  }

  for _, arg in ipairs(args) do
    table.insert(command, arg)
  end

  local ok, success, stdout, _ = pcall(wezterm.run_child_process, command)
  if not ok or not success then
    return false, nil
  end

  return true, stdout
end

---@param wsl_distro string
---@param linux_dir string
---@return boolean
function M.ensure_dir(wsl_distro, linux_dir)
  local success = run_wsl_command(wsl_distro, {
    'mkdir',
    '-p',
    linux_dir,
  })

  return success
end

---@param wsl_distro string
---@param linux_path string
---@return string|nil
function M.path_to_windows(wsl_distro, linux_path)
  local success, stdout = run_wsl_command(wsl_distro, {
    'wslpath',
    '-w',
    linux_path,
  })

  if not success or not stdout then
    return nil
  end

  local windows_path = strings.trim(stdout)
  if windows_path == '' then
    return nil
  end

  return windows_path
end

---@param wsl_distro string
---@param linux_path string
---@return string|nil
function M.path_to_windows_cached(wsl_distro, linux_path)
  local key = windows_path_cache_key(wsl_distro, linux_path)
  local cached = cached_windows_paths[key]
  if cached then
    return cached
  end

  local windows_path = M.path_to_windows(wsl_distro, linux_path)
  if not windows_path then
    return nil
  end

  cached_windows_paths[key] = windows_path
  return windows_path
end

---Set the preferred WSL distro name.
---
---Accepts either:
--- - a distro name like `Ubuntu`
--- - or a domain name like `WSL:Ubuntu`
---
---Set to nil/empty string to disable preference.
---@param value? string
function M.set_preferred(value)
  if value == nil or value == '' then
    preferred = nil
    return
  end

  preferred = value:gsub('^WSL:', '')
end

---@param wsl_domains WslDomain[]
---@return string|nil
local function find_default_wsl_domain(wsl_domains)
  if preferred then
    for _, domain in ipairs(wsl_domains) do
      local distro = M.distro_from_domain_name(domain.name) or domain.name
      if distro == preferred then
        return domain.name
      end
    end
  end

  if #wsl_domains > 0 then
    return wsl_domains[1].name
  end

  return nil
end

---@return WslDomain[]
function M.domains()
  if not platform.is_win then
    return {}
  end

  if cached_domains then
    return cached_domains
  end

  cached_domains = wezterm.default_wsl_domains()
  return cached_domains
end

---@return string|nil
function M.default_domain_name()
  if not platform.is_win then
    return nil
  end

  return find_default_wsl_domain(M.domains())
end

---@return string|nil
function M.default_distro()
  local name = M.default_domain_name()
  if not name then
    return nil
  end

  return M.distro_from_domain_name(name) or name
end

return M
