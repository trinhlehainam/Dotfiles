local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.lspconfigs = { LspConfig:new('nginx_language_server', 'nginx-language-server') }

return M
