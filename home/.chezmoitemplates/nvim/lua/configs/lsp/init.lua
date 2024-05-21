--- @class custom.Lsp
--- @field language_settings table<string, custom.LanguageSetting>

--- @type custom.Lsp
local M = {
  language_settings = {},
}

local ignore_mods = { 'base', 'init', 'utils' }

M.language_settings = require('utils.path').load_mods('configs.lsp', ignore_mods)

return M
