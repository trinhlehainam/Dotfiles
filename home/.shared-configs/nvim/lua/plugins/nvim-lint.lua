return { -- Linter
  'mfussenegger/nvim-lint',
  event = {
    'BufReadPre',
    'BufNewFile',
  },
  config = function()
    require('configs.plugins.nvim-lint')
  end,
}
