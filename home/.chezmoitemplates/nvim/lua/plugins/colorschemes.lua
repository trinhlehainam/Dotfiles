return {
  {
    'rebelot/kanagawa.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme('kanagawa')
    end,
  },
  'folke/tokyonight.nvim',
  'navarasu/onedark.nvim',
  {
    'f4z3r/gruvbox-material.nvim',
    name = 'gruvbox-material',
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
  },
}
