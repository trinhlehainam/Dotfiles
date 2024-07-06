local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "go", "gomod", "gowork", "gotmpl" }

-- NOTE: ruff is an running server that watching python files
M.formatterconfig.servers = { "gofumpt", "goimports-reviser", "golines" }
M.formatterconfig.formatters_by_ft = {
	go = {
		"gofumpt",
		"goimports-reviser",
		"golines",
	},
}

local gopls = LspConfig:new("gopls")
gopls.setup = function(capabilities, on_attach)
	require("lspconfig")[gopls.server].setup({
		capabilities = capabilities,
		on_attach = on_attach,
	})
end

M.lspconfigs = { gopls }

M.dapconfig.type = "delve"

return M
