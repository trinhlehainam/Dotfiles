local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

M.formatterconfig.servers = { "rustywind" }

local tailwindcss = LspConfig:new("tailwindcss")
tailwindcss.setup = function(capabilities, _)
	local log = require("utils.log")
	local haslspconfig, lspconfig = pcall(require, "lspconfig")

	if not haslspconfig then
		log.error("lspconfig is not installed")
		return
	end

	lspconfig[tailwindcss.server].setup({
		capabilities = capabilities,
	})
end
M.lspconfigs = { tailwindcss }

M.after_masonlsp_setup = function()
	local log = require("utils.log")
	local hastailwindtools, tailwindtools = pcall(require, "tailwind-tools")

	if not hastailwindtools then
		log.error("tailwind-tools is not installed")
		return
	end

	tailwindtools.setup({})
end

return M
