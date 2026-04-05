local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

-- NOTE: https://github.com/nushell/nu_scripts

M.treesitter.filetypes = { 'nu' }

if vim.fn.executable('nu') == 0 then
  require('utils.log').info('Nushell is not installed')
  return M
end

M.lspconfigs = { LspConfig:new('nushell') }

return M
