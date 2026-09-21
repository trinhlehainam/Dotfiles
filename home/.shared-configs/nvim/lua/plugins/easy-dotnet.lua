return {
  -- https://github.com/GustavEikaas/easy-dotnet.nvim
  'GustavEikaas/easy-dotnet.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'folke/snacks.nvim', 'mfussenegger/nvim-dap' },
  config = function()
    -- roslyn.nvim owns the C# server; easy-dotnet owns project commands and debugging.
    require('easy-dotnet').setup({ lsp = { enabled = false } })
  end,
}
