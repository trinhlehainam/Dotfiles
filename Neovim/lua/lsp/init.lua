--- @class custom.Lsp
--- @field langs table<string, custom.Lang>
--- @field utils? table

--- @type custom.Lsp
local M = {
  langs = {},
}

local ignore_mods = { 'base', 'init', 'utils' }

M.langs = require('utils').load_mods("lsp", ignore_mods)

return M
