---@type dotfiles.lsp.Language
return {
  parsers = { 'php' },
  tools = { 'intelephense', 'blade-formatter', 'php-cs-fixer', 'phpstan', 'phpcs' },
  servers = {
    intelephense = vim.tbl_extend('force', require('features.intelephense'), {
      settings = {
        intelephense = {
          codeLens = {
            references = { enable = true },
            implementations = { enable = true },
            usages = { enable = true },
            overrides = { enable = true },
            parent = { enable = true },
          },
        },
      },
    }),
  },
  formatters = { blade = { 'blade-formatter' }, php = { 'php_cs_fixer' } },
  linters = { php = { 'phpstan', 'phpcs' } },
  lint_on_save = false,
  dap = { 'php' },
  neotest = function()
    return require('neotest-phpunit')
  end,
}
