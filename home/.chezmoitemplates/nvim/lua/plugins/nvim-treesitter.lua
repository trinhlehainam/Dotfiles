return { -- Highlight, edit, and navigate code
  -- https://github.com/nvim-treesitter/nvim-treesitter/tree/main
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  branch = 'main',
  build = ':TSUpdate',
  dependencies = {
    {
      -- https://github.com/nvim-treesitter/nvim-treesitter-textobjects/tree/main
      'nvim-treesitter/nvim-treesitter-textobjects',
      branch = 'main',
      init = function()
        -- Disable entire built-in ftplugin mappings to avoid conflicts.
        -- See https://github.com/neovim/neovim/tree/master/runtime/ftplugin for built-in ftplugins.
        vim.g.no_plugin_maps = true

        -- Or, disable per filetype (add as you like)
        -- vim.g.no_python_maps = true
        -- vim.g.no_ruby_maps = true
        -- vim.g.no_rust_maps = true
        -- vim.g.no_go_maps = true
      end,
    },
    { 'nvim-treesitter/nvim-treesitter-context', opts = {} },
    { 'nushell/tree-sitter-nu' },
  },
  config = function()
    require('configs.plugins.nvim-treesitter')
    require('configs.plugins.nvim-treesitter-textobjects')
  end,
}
