return { -- Formatter
  --- TODO: https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  config = function()
    require('configs.plugins.conform')
  end,
}
