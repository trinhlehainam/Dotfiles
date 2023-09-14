local M = {}
local curr_dir = vim.fn.stdpath('config') .. '/lua/lsp'
local utils = require('utils')

local ignore_mods = { 'base', 'init' }

M = utils.load_mods_in_dir(curr_dir, ignore_mods)

return M
