local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tailwindcss"
M.lspconfig.use_setup = true

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

	local hastailwindsorter, tailwindsorter = pcall(require, "tailwind-sorter")
	if not hastailwindsorter then
		log.error("tailwind-sorter is not installed")
		return
	end

	tailwindsorter.setup({
		on_save_patterns = { "*.html", "*.js", "*.jsx", "*.ts", "*.tsx", "*.vue" },
	})
end

M.config = tailwindtools_config

return M
