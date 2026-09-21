return {
  -- https://github.com/mrcjkb/rustaceanvim
  'mrcjkb/rustaceanvim',
  dependencies = {
    'neovim/nvim-lspconfig',
    'mfussenegger/nvim-dap',
  },
  version = '^6', -- Recommended
  lazy = false, -- This plugin is already lazy
}
