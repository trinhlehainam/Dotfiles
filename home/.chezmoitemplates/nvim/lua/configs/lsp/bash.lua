local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "bash" }

M.formatterconfig.servers = { "shfmt" }
M.formatterconfig.formatters_by_ft = {
	bash = { "shfmt" },
}

M.linterconfig.servers = { "shellcheck" }
M.linterconfig.linters_by_ft = {
	bash = { "shellcheck" },
}

M.lspconfig.server = "bashls"

return M
