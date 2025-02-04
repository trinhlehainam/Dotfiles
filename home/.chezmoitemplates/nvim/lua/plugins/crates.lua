return {
  'saecki/crates.nvim',
  tag = 'stable',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('configs.plugins.crates')
  end,
}
