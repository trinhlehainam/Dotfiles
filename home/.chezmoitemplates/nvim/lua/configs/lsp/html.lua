local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'html' }
M.lspconfigs = { LspConfig:new('html', 'html-lsp') }

return M
