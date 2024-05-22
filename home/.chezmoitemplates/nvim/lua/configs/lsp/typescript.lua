local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tsserver"
M.lspconfig.use_setup = false

M.formatterconfig.servers = { "prettierd" }
M.formatterconfig.formatters_by_ft = {
	javascript = { "prettierd" },
	typescript = { "prettierd" },
	javascriptreact = { "prettierd" },
	typescriptreact = { "prettierd" },
	vue = { "prettierd" },
}

M.linterconfig.servers = { "eslint_d" }
M.linterconfig.linters_by_ft = {
	javascript = { "eslint_d" },
	typescript = { "eslint_d" },
	javascriptreact = { "eslint_d" },
	typescriptreact = { "eslint_d" },
	vue = { "eslint_d" },
}

return M
