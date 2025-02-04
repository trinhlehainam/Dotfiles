-- INFO: https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim/issues/39

local M = {
  install = nil,

  get_mason_path = nil,

  get_mason_package_path = nil,
}

local log = require('utils.log')

M.has_mason = function()
  local hasregistry, _ = pcall(require, 'mason-registry')
  local hasmasonsettings, _ = pcall(require, 'mason.settings')
  if not hasregistry or not hasmasonsettings then
    return false
  end

  return true
end

---@param ensure_installed string[]
local function install(ensure_installed)
  local hasregistry, registry = pcall(require, 'mason-registry')
  if not hasregistry then
    return
  end

  return function()
    if not vim.islist(ensure_installed) then
      log.error('ensure_installed must be a list')
      return
    end
    for _, pkg_name in ipairs(ensure_installed) do
      local ok, pkg = pcall(registry.get_package, pkg_name)
      if ok and not pkg:is_installed() then
        log.info(('Installing %s'):format(pkg.name))
        pkg:install():once(
          'closed',
          vim.schedule_wrap(function()
            if pkg:is_installed() then
              log.info(('%s was installed'):format(pkg.name))
            end
          end)
        )
      end
    end
  end
end

M.install = function(ensure_installed)
  local hasregistry, registry = pcall(require, 'mason-registry')
  if not hasregistry then
    return
  end
  local install_callback = install(ensure_installed)
  if type(install_callback) ~= 'function' then
    return
  end

  if registry.refresh then
    registry.refresh(vim.schedule_wrap(install_callback))
  else
    install_callback()
  end
end

---@return string
M.get_mason_path = function()
  local hasmasonsettings, masonsettings = pcall(require, 'mason.settings')
  if not hasmasonsettings then
    return ''
  end
  return masonsettings.current.install_root_dir
end

---@param pkg_name string
---@return string | nil
M.get_mason_package_path = function(pkg_name)
  local hasregistry, registry = pcall(require, 'mason-registry')
  if not hasregistry then
    return nil
  end

  local ok, pkg = pcall(registry.get_package, pkg_name)
  if not ok then
    return nil
  end
  return pkg:get_install_path()
end

return M
