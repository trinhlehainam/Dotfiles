return {
  'rebelot/kanagawa.nvim',
  'folke/tokyonight.nvim',
  'navarasu/onedark.nvim',
  'ellisonleao/gruvbox.nvim',
  'catppuccin/nvim',
  {
    'sainnhe/gruvbox-material',
    config = function()
      vim.cmd.colorscheme('gruvbox-material')
    end,
  },
}
