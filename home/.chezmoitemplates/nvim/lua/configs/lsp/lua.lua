local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'lua' }

-- TODO: https://github.com/folke/lazydev.nvim/issues/136#issuecomment-3773651709
local lua_ls =
  LspConfig:new('lua_ls', { 'lua-language-server', version = '3.16.4', auto_update = false })
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

M.formatterconfig.mason_packages = { 'stylua' }
M.formatterconfig.formatters_by_ft = {
  lua = { 'stylua' },
}

return M
