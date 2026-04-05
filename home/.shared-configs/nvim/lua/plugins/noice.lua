return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  dependencies = {
    -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
    'MunifTanjim/nui.nvim',
    { 'rcarriga/nvim-notify', opts = {
      background_colour = '#000000',
    } },
    'folke/snacks.nvim',
  },
  config = function()
    require('configs.plugins.noice').setup()
  end,
}
