local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

-- https://github.com/GustavEikaas/easy-dotnet.nvim?tab=readme-ov-file#requirements-5
M.treesitter.filetypes = { 'c_sharp', 'sql', 'json', 'xml' }

M.lspconfigs = { LspConfig:new(nil, 'roslyn') }

-- https://github.com/GustavEikaas/easy-dotnet.nvim/blob/main/docs/debugging.md
-- TODO: Add DAP config

return M
