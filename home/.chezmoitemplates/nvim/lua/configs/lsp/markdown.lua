local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'markdown', 'markdown_inline' }

M.lspconfigs = { LspConfig:new('marksman', 'marksman') }

return M
