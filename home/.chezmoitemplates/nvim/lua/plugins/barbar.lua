return {
  {
    --- https://github.com/romgrk/barbar.nvim
    'romgrk/barbar.nvim',
    dependencies = {
      'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
      'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
    },
    version = '^1.0.0', -- optional: only update when a new 1.x version is released
    init = function()
      vim.g.barbar_auto_setup = false
    end,
    opts = {
      -- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
      animation = false,
      auto_hide = true,
    },
    keys = {
      { 'b1', '<cmd>BufferGoto 1<CR>', desc = 'Go to [B]uffer 1' },
      { 'b2', '<cmd>BufferGoto 2<CR>', desc = 'Go to [B]uffer 2' },
      { 'b3', '<cmd>BufferGoto 3<CR>', desc = 'Go to [B]uffer 3' },
      { 'b4', '<cmd>BufferGoto 4<CR>', desc = 'Go to [B]uffer 4' },
      { 'b5', '<cmd>BufferGoto 5<CR>', desc = 'Go to [B]uffer 5' },
      { 'bj', '<cmd>BufferPrevious<CR>', desc = '[B]uffer Previous' },
      { 'bk', '<cmd>BufferNext<CR>', desc = '[B]uffer Next' },
      { 'bl', '<cmd>BufferLast<CR>', desc = '[B]uffer Last' },
      { 'bh', '<cmd>BufferFirst<CR>', desc = '[B]uffer First' },
      { 'bJ', '<cmd>BufferMovePrevious<CR>', desc = '[B]uffer Move Previous' },
      { 'bK', '<cmd>BufferMoveNext<CR>', desc = '[B]uffer Move Next' },
      { 'bH', '<cmd>BufferMoveStart<CR>', desc = '[B]uffer Move First' },
      { 'bc', '<cmd>BufferClose<CR>', desc = '[B]uffer Close' },
    },
  },
}
