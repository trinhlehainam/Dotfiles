return {
  {
    'rebelot/kanagawa.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme('kanagawa')
    end,
  },
  { 'folke/tokyonight.nvim', lazy = true },
  { 'navarasu/onedark.nvim', lazy = true },
  {
    'f4z3r/gruvbox-material.nvim',
    name = 'gruvbox-material',
    lazy = true,
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = true,
  },
}
