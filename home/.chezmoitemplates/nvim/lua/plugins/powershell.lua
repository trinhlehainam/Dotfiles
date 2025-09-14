return {
  'TheLeoP/powershell.nvim',
  dependencies = { 'williamboman/mason.nvim' },
  config = function()
    require('powershell').setup({
      -- https://github.com/TheLeoP/powershell.nvim?tab=readme-ov-file#configuration
      -- https://github.com/mason-org/mason.nvim/blob/main/CHANGELOG.md#package-api-changes
      bundle_path = vim.fn.expand('$MASON/packages/powershell-editor-services'),
    })
  end,
}
