local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tailwindcss"

M.formatterconfig.servers = { "rustywind" }

---@param capabilities lsp.ClientCapabilities
---@param _ fun(client: lsp.Client, bufnr: integer)
local function setup(capabilities, _)
	local log = require("utils.log")
	local haslspconfig, lspconfig = pcall(require, "lspconfig")

	if not haslspconfig then
		log.error("lspconfig is not installed")
		return
	end

	lspconfig[M.lspconfig.server].setup({
		capabilities = capabilities,
	})
end

M.lspconfig.setup = setup

local function tailwindtools_config()
	local log = require("utils.log")
	local hastailwindtools, tailwindtools = pcall(require, "tailwind-tools")

	if not hastailwindtools then
		log.error("tailwind-tools is not installed")
		return
	end

	tailwindtools.setup({})
end

M.after_masonlsp_setup = tailwindtools_config

return M
