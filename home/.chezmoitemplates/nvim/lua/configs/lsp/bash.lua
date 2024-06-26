local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "bash" }

M.formatterconfig.servers = { "shfmt" }
M.formatterconfig.formatters_by_ft = {
	bash = { "shfmt" },
	sh = { "shfmt" },
}

M.linterconfig.servers = { "shellcheck" }
M.linterconfig.linters_by_ft = {
	bash = { "shellcheck" },
	sh = { "shellcheck" },
}

M.lspconfig.server = "bashls"

return M
