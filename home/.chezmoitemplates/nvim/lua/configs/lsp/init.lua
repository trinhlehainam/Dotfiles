--- @class custom.Lsp
--- @field treesitters custom.TreeSitter[]
--- @field lspconfigs custom.LspConfig[]
--- @field dapconfigs table<string, custom.DapConfig>
--- @field formatters custom.FormatterConfig[]
--- @field linters custom.LinterConfig[]
--- @field after_masonlsp_setups function[]

--- @type custom.Lsp
local M = {
	treesitters = {},
	lspconfigs = {},
	dapconfigs = {},
	formatters = {},
	linters = {},
	after_masonlsp_setups = {},
}

local ignore_mods = { "types", "base", "init", "lspconfig" }

--- @type table<string, custom.LanguageSetting>
local language_settings = require("utils.common").load_mods("configs.lsp", ignore_mods)

for lang, settings in pairs(language_settings) do
	table.insert(M.treesitters, settings.treesitter)
	M.dapconfigs[lang] = settings.dapconfig
	vim.list_extend(M.lspconfigs, settings.lspconfigs)
	table.insert(M.formatters, settings.formatterconfig)
	table.insert(M.linters, settings.linterconfig)
	table.insert(M.after_masonlsp_setups, settings.after_masonlsp_setup)
end

return M
