local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

local log = require('utils.log')

if not vim.fn.executable('ruby') then
  log.info('ruby-lsp requires ruby to be installed')
  log.info(
    'install ruby following instructions: https://github.com/rbenv/rbenv?tab=readme-ov-file#using-package-managers'
  )
  return M
end

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
-- To solve cannot load such file -- zlib on WSL: https://stackoverflow.com/a/78110911
M.lspconfigs = { LspConfig:new('ruby_lsp') }

return M
