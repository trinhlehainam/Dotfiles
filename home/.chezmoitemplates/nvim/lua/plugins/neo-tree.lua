return {
  -- https://github.com/nvim-neo-tree/neo-tree.nvim
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
    -- Optional image support for file preview: See `# Preview Mode` for more information.
    -- {"3rd/image.nvim", opts = {}},
    -- OR use snacks.nvim's image module:
    -- "folke/snacks.nvim",
  },
  lazy = false, -- neo-tree will lazily load itself
  ---@module "neo-tree"
  ---@type neotree.Config?
  opts = {
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
        -- hide_by_name = {
        --   '.git',
        -- },
      },
    },
  },
  keys = {
    { '<leader>tt', '<cmd>Neotree<cr>', desc = '[T]oggle Neo[T]ree' },
    { '<A-,>', '<c-w>5<', ft = 'neo-tree' },
    { '<A-.>', '<c-w>5>', ft = 'neo-tree' },
  },
}
