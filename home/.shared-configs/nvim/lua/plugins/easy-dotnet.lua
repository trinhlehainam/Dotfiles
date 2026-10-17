return {
  -- https://github.com/GustavEikaas/easy-dotnet.nvim
  'GustavEikaas/easy-dotnet.nvim',
  -- Startup argument buffers exist before BufNew handlers can be registered.
  lazy = not vim.iter(vim.fn.argv()):any(function(path)
    return path:match('%.cs$') ~= nil
  end),
  cmd = 'Dotnet',
  ft = { 'cs', 'fsharp', 'vb', 'razor' },
  -- Load before C# bootstrap hooks and project filetype detection are needed.
  event = {
    {
      event = { 'BufNew', 'BufReadPre', 'BufNewFile' },
      pattern = {
        '*.cs',
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
