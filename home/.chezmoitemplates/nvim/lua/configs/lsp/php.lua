local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

local log = require('utils.log')
local common = require('utils.common')

if common.IS_WINDOWS then
  log.info('php language server is not supported on Windows')
  return M
end

M.treesitter.filetypes = { 'php' }

M.formatterconfig.servers = { 'blade-formatter', 'php-cs-fixer' }
M.formatterconfig.formatters_by_ft = {
  blade = { 'blade-formatter' },
  -- php = { "php-cs-fixer" },
  -- php = { "easy-coding-standard" },
}

M.linterconfig.servers = { 'phpcs' }
M.linterconfig.linters_by_ft = {
  -- php = { "phpcs" },
  -- php = { "easy-coding-standard" },
}

local phpactor = LspConfig:new('phpactor')
phpactor.setup = function(capabilities, on_attach)
  -- NOTE: laravel.nvim use lspconfig to detect installed servers
  -- Need to set up lspconfig first
  require('lspconfig')[phpactor.server].setup({
    capabilities = capabilities,
    on_attach = on_attach,
  })
end
M.lspconfigs = { phpactor }

M.after_masonlsp_setup = function()
  local haslaravel, laravel = pcall(require, 'laravel')

  if not haslaravel then
    log.error('laravel.nvim is not installed')
    return
  end

  laravel.setup({
    features = {
      null_ls = {
        enable = false,
      },
    },
  })

  vim.keymap.set('n', '<leader>la', ':Laravel artisan<cr>', { desc = '[L]aravel [A]rtisan' })
  vim.keymap.set('n', '<leader>lm', ':Laravel related<cr>', { desc = '[L]aravel [R]elated' })
  vim.keymap.set('n', '<leader>lr', ':Laravel routes<cr>', { desc = 'Find [L]aravel [R]outes' })
end

return M
