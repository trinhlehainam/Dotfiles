local wezterm = require('wezterm') ---@type Wezterm

local platform = require('utils.platform')

local M = {}

---@type WslDomain[]|nil
local cached_domains = nil

---@type string|nil
local preferred = nil

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
      local distro = domain.name:gsub('^WSL:', '')
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

  return name:gsub('^WSL:', '')
end

return M
