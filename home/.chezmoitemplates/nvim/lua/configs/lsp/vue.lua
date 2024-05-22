local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "volar"
M.lspconfig.setup = function(capabilities, on_attach)
	local log = require("utils.log")
	local haslspconfig, lspconfig = pcall(require, "lspconfig")

	if not haslspconfig then
		log.error("lspconfig is not installed")
		return
	end

	lspconfig[M.lspconfig.server].setup({
		on_attach = on_attach,
		capabilities = capabilities,
		init_options = {
			vue = {
				hybridMode = false,
			},
		},
	})
end

return M
