local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "bash" }

M.formatterconfig.servers = { "shellharden" }
M.formatterconfig.formatters_by_ft = {
	bash = { "shellharden" },
	sh = { "shellharden" },
}

M.linterconfig.servers = { "shellcheck" }
M.linterconfig.linters_by_ft = {
	bash = { "shellcheck" },
	sh = { "shellcheck" },
}

local bashls = LspConfig:new("bashls")
M.lspconfigs = { bashls }

return M
