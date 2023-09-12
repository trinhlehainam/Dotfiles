return {
   'folke/tokyonight.nvim',
   'navarasu/onedark.nvim',
   'ellisonleao/gruvbox.nvim',
   {
      'sainnhe/gruvbox-material',
      config = function()
         vim.cmd.colorscheme 'gruvbox-material'
      end
   }
}
