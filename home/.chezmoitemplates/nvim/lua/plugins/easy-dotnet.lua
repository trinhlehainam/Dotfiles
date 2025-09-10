return {
  -- https://github.com/GustavEikaas/easy-dotnet.nvim
  'GustavEikaas/easy-dotnet.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
  config = function()
    require('easy-dotnet').setup()
  end,
}
