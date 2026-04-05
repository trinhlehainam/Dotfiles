return { -- Linter
  'mfussenegger/nvim-lint',
  dependencies = { 'WhoIsSethDaniel/mason-tool-installer.nvim' },
  event = {
    'BufReadPre',
    'BufNewFile',
  },
  config = function()
    require('configs.plugins.nvim-lint')
  end,
}
