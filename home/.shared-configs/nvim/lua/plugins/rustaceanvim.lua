return {
  -- https://github.com/mrcjkb/rustaceanvim
  'mrcjkb/rustaceanvim',
  dependencies = {
    'neovim/nvim-lspconfig',
  },
  version = '^6', -- Recommended
  lazy = false, -- This plugin is already lazy
  init = function()
    -- Keep Rust test commands using Neotest even before its first lazy load.
    vim.g.rustaceanvim = { tools = { test_executor = 'neotest' } }
  end,
}
