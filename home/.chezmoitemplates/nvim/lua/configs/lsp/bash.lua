local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

-- https://github.com/davidosomething/dotfiles/blob/dev/nvim/lua/dko/filetypes.lua
vim.filetype.add({
  extension = {
    conf = 'conf',
    env = 'dotenv',
  },
  filename = {
    ['.env'] = 'dotenv',
  },
  pattern = {
    ['%.env%.[%w_.-]+'] = 'dotenv',
  },
})

M.treesitter.filetypes = { 'bash' }

M.formatterconfig.servers = { 'shellharden' }
M.formatterconfig.formatters_by_ft = {
  bash = { 'shellharden' },
  sh = { 'shellharden' },
}

M.linterconfig.servers = { 'shellcheck' }
M.linterconfig.linters_by_ft = {
  bash = { 'shellcheck' },
  sh = { 'shellcheck' },
}

local bashls = LspConfig:new('bashls', 'bash-language-server')
M.lspconfigs = { bashls }

return M
