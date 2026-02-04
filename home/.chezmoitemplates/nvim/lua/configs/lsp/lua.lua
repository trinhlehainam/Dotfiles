local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'lua' }

local lua_ls = LspConfig:new('lua_ls', 'lua-language-server')
lua_ls.config = {
  settings = {
    Lua = {
      completion = {
        callSnippet = 'Replace',
      },
      codeLens = {
        enable = true,
      },
    },
  },
}
M.lspconfigs = { lua_ls }

M.formatterconfig.servers = { 'stylua' }
M.formatterconfig.formatters_by_ft = {
  lua = { 'stylua' },
}

return M
