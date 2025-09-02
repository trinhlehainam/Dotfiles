local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.formatterconfig.servers = { 'rustywind' }

local tailwindcss = LspConfig:new('tailwindcss', 'tailwindcss-language-server')
M.lspconfigs = { tailwindcss }

return M
