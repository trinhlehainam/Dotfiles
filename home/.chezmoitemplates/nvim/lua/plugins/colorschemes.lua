return {
  'rebelot/kanagawa.nvim',
  'folke/tokyonight.nvim',
  'navarasu/onedark.nvim',
  'sainnhe/gruvbox-material',
  'ellisonleao/gruvbox.nvim',
  'sainnhe/everforest',
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    config = function()
      vim.cmd.colorscheme('catppuccin')
    end,
  },
}
