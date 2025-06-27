return { -- Formatter
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  dependencies = { 'WhoIsSethDaniel/mason-tool-installer.nvim' },
  lazy = false,
  keys = {
    {
      '<leader>fm',
      function()
        require('conform').format({ async = true, lsp_fallback = true })
      end,
      mode = '',
      desc = '[F]or[m]at buffer',
    },
  },
  config = function()
    require('configs.plugins.conform')
  end,
}
