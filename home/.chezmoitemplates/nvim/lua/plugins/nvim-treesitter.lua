return { -- Highlight, edit, and navigate code
  -- https://github.com/nvim-treesitter/nvim-treesitter/tree/main
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  branch = 'main',
  build = ':TSUpdate',
  dependencies = {
    -- 'nvim-treesitter/nvim-treesitter-textobjects',
    -- { 'nvim-treesitter/nvim-treesitter-context', opts = {} },
    { 'nushell/tree-sitter-nu' },
    -- TODO: some tree-sitter extension require manually install
    -- { "EmranMR/tree-sitter-blade" },
  },
  config = function()
    require('configs.plugins.nvim-treesitter')
  end,
}
