return {
  'saecki/crates.nvim',
  tag = 'stable',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    { '<leader>c', nil, desc = 'Rust [C]rates' },
  },
  config = function()
    require('configs.plugins.crates')
  end,
}
