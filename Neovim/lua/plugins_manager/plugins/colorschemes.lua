return {
   'rebelot/kanagawa.nvim',
   {
      'folke/tokyonight.nvim',
      config = function()
         vim.cmd.colorscheme 'tokyonight-storm'
      end
   },
   'navarasu/onedark.nvim',
   'ellisonleao/gruvbox.nvim',
   'sainnhe/gruvbox-material',
}
