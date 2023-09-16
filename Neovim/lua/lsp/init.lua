--- @type table<string, Lang>
local M = {}
local utils = require('utils')

local ignore_mods = { 'base', 'init' }

M = utils.load_mods("lsp", ignore_mods)

return M
