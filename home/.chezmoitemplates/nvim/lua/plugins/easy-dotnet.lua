return {
  -- https://github.com/GustavEikaas/easy-dotnet.nvim
  'GustavEikaas/easy-dotnet.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'folke/snacks.nvim' },
  config = function()
    -- Uses vim.ui.select which is handled by snacks.picker (ui_select = true)
    require('easy-dotnet').setup()
  end,
}
