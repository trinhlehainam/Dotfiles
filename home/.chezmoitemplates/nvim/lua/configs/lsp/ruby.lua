local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()
M.treesitter.filetypes = { 'ruby' }

M.formatterconfig.servers = { 'rubocop' }
M.formatterconfig.formatters_by_ft = {
  ruby = { 'rubocop' },
}

M.linterconfig.servers = { 'rubocop' }
M.linterconfig.linters_by_ft = {
  ruby = { 'rubocop' },
}

-- Use rbenv to manage Ruby versions: https://github.com/rbenv/rbenv?tab=readme-ov-file#using-package-managers
-- Install ruby-lsp with mason: https://shopify.github.io/ruby-lsp/editors.html#mason
-- To solve cannot load such file -- zlib on WSL: https://stackoverflow.com/a/78110911
M.lspconfigs = { LspConfig:new('ruby_lsp') }

return M
