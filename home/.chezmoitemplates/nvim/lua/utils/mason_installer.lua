-- Ref: https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim/issues/39

local M = {
	---@type fun(ensure_installed: string[]) | nil
	install = nil,
}

local log = require("utils.log")
local hasregister, registry = pcall(require, "mason-registry")

if not hasregister then
	log.error("mason.nvim is not installed")
	return M
end

---@param ensure_installed string[]
local function install(ensure_installed)
	return
		function()
			if not vim.islist(ensure_installed) then
				log.error("ensure_installed must be a list")
				return
			end
			for _, pkg_name in ipairs(ensure_installed) do
				local ok, pkg = pcall(registry.get_package, pkg_name)
				if ok and not pkg:is_installed() then
					log.info(("Installing %s"):format(pkg.name))
					pkg:install():once(
						"closed",
						vim.schedule_wrap(function()
							if pkg:is_installed() then
								log.info(("%s was installed"):format(pkg.name))
							end
						end)
					)
				end
			end
		end
end

M.install = function(ensure_installed)
	if registry.refresh then
		registry.refresh(vim.schedule_wrap(install(ensure_installed)))
	else
		install(ensure_installed)
	end
end

return M
