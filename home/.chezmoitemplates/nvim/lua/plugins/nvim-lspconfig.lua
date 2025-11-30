return { -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    'folke/snacks.nvim',
    -- Automatically install LSPs and related tools to stdpath for Neovim
    -- Mason must be loaded before its dependents so we need to set it up here.
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    -- https://github.com/mason-org/mason.nvim
    {
      'mason-org/mason.nvim',
      config = function()
        require('mason').setup({
          -- https://github.com/seblyng/roslyn.nvim?tab=readme-ov-file#-installation
          registries = {
            'github:mason-org/mason-registry',
            'github:Crashdummyy/mason-registry',
          },
        })
      end,
    },
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP
    { 'j-hui/fidget.nvim', opts = {} },

    -- Allows extra capabilities provided by blink.cmp
    'saghen/blink.cmp',
  },
  config = function()
    require('configs.plugins.nvim-lspconfig')
  end,
}
