local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'awk' }

local awk_ls = LspConfig:new('awk_ls', 'awk-language-server')

M.lspconfigs = { awk_ls }

return M
