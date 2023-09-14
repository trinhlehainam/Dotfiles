local M = {}
local utils = require('utils')

local ignore_mods = { 'base', 'init' }

M = utils.load_mods_by_modname("lsp", ignore_mods)

return M
