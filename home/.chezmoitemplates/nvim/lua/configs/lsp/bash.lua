local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "bash" }

M.formatterconfig.servers = { "shfmt" }
M.formatterconfig.formatters_by_ft = {
	bash = { "shfmt" },
}

M.linterconfig.servers = { "shellharden" }
M.linterconfig.linters_by_ft = {
	bash = { "shellharden" },
}

M.lspconfig.server = "bashls"

return M
