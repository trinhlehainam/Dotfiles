return {
  -- https://github.com/GustavEikaas/easy-dotnet.nvim
  'GustavEikaas/easy-dotnet.nvim',
  cmd = 'Dotnet',
  ft = { 'cs', 'fsharp', 'vb', 'razor' },
  -- Project files activate tooling too; load before detection to register XML/JSON5.
  event = {
    {
      event = { 'BufReadPre', 'BufNewFile' },
      pattern = {
        '*.sln',
        '*.slnx',
        '*.slnf',
        '*.csproj',
        '*.fsproj',
        '*.vbproj',
        '*.props',
        '*.targets',
        'appsettings*.json',
        'launchSettings.json',
        'secrets.json',
      },
    },
  },
  dependencies = { 'nvim-lua/plenary.nvim', 'folke/snacks.nvim', 'mfussenegger/nvim-dap' },
  config = function()
    -- roslyn.nvim owns the C# server; easy-dotnet owns project commands and debugging.
    require('easy-dotnet').setup({ lsp = { enabled = false } })
  end,
}
