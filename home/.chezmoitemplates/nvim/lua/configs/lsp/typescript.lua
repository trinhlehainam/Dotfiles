local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tsserver"
M.lspconfig.setup = function(_, _)
	-- NOTE: typescript-tools will automatically configure tsserver in nvim-lspconfig
end

M.linterconfig.servers = { "eslint_d" }
M.linterconfig.linters_by_ft = {
	javascript = { "eslint_d" },
	typescript = { "eslint_d" },
	javascriptreact = { "eslint_d" },
	typescriptreact = { "eslint_d" },
	svelte = { "eslint_d" },
	vue = { "eslint_d" },
}

return M
