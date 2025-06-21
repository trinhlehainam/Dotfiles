return { -- Highlight, edit, and navigate code
  -- https://github.com/nvim-treesitter/nvim-treesitter/tree/main
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  branch = 'main',
  build = ':TSUpdate',
  dependencies = {
    { 'nvim-treesitter/nvim-treesitter-textobjects' },
    { 'nushell/tree-sitter-nu' },
    -- TODO: some tree-sitter extension require manually install
    -- { "EmranMR/tree-sitter-blade" },
  },
  config = function()
    require('treesitter-context').setup({})
    require('configs.plugins.nvim-treesitter')
  end,
}
