return {
  'saecki/crates.nvim',
  tag = 'stable',
  keys = {
    { '<leader>c', nil, desc = 'Rust [C]rates' },
  },
  config = function()
    require('configs.plugins.crates')
  end,
}
