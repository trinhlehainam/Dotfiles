return {
  'rebelot/kanagawa.nvim',
  'folke/tokyonight.nvim',
  'navarasu/onedark.nvim',
  {
    'f4z3r/gruvbox-material.nvim',
    name = 'gruvbox-material',
    lazy = false,
    priority = 1000,
    -- https://github.com/f4z3r/gruvbox-material.nvim?tab=readme-ov-file#usage-and-configuration
    opts = {
      constrast = 'hard',
    },
    config = function()
      vim.cmd.colorscheme('gruvbox-material')
    end,
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
  },
}
