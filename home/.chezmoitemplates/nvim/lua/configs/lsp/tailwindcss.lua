local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tailwindcss"
M.lspconfig.use_setup = true

---@param capabilities lsp.ClientCapabilities
---@param on_attach fun(client: lsp.Client, bufnr: integer)
local function setup(capabilities, on_attach)
	local log = require("utils.log")
	local haslspconfig, lspconfig = pcall(require, "lspconfig")

	if not haslspconfig then
		log.error("lspconfig is not installed")
		return
	end

	lspconfig[M.lspconfig.server].setup({
		capabilities = capabilities,
		-- on_attach = on_attach,
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

M.config = tailwindtools_config

return M
