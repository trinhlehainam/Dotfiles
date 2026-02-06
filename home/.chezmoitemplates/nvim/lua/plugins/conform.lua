return { -- Formatter
  --- TODO: https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  dependencies = { 'WhoIsSethDaniel/mason-tool-installer.nvim' },
  config = function()
    require('configs.plugins.conform')
  end,
}
