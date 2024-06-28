--- @class custom.Lsp
--- @field treesitters table<string, custom.TreeSitter>
--- @field lspconfigs table<string, custom.LspConfig>
--- @field dapconfigs table<string, custom.DapConfig>
--- @field formatters table<string, custom.FormatterConfig>
--- @field linters table<string, custom.LinterConfig>
--- @field after_masonlsp_setups table<string, fun()>

--- @type custom.Lsp
local M = {
	treesitters = {},
	lspconfigs = {},
	dapconfigs = {},
	formatters = {},
	linters = {},
	after_masonlsp_setups = {},
}

local ignore_mods = { "base", "init", "utils" }

--- @type table<string, custom.LanguageSetting>
local language_settings = require("utils.common").load_mods("configs.lsp", ignore_mods)

for lang, settings in pairs(language_settings) do
	M.treesitters[lang] = settings.treesitter
	M.lspconfigs[lang] = settings.lspconfig
	M.dapconfigs[lang] = settings.dapconfig
	M.formatters[lang] = settings.formatterconfig
	M.linters[lang] = settings.linterconfig
	M.after_masonlsp_setups[lang] = settings.after_masonlsp_setup
end

return M
