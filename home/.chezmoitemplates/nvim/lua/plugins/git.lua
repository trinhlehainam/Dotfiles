return {
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim', -- required
      'sindrets/diffview.nvim', -- optional - Diff integration
    },
    config = function()
      local neogit = require('neogit')
      neogit.setup({
        mappings = {
          -- Setting any of these to `false` will disable the mapping.
          popup = {},
          status = {},
        },
      })

      local diffview = require('diffview')
      diffview.setup()

      vim.keymap.set(
        'n',
        '<leader>gs',
        neogit.open,
        { desc = '[S]how [G]it', silent = true, noremap = true }
      )
      vim.keymap.set(
        'n',
        '<leader>gc',
        ':Neogit commit<CR>',
        { desc = '[G]it [C]ommit', silent = true, noremap = true }
      )
      vim.keymap.set(
        'n',
        '<leader>gp',
        ':Neogit pull<CR>',
        { desc = '[G]it [P]ull', silent = true, noremap = true }
      )
      vim.keymap.set(
        'n',
        '<leader>gP',
        ':Neogit push<CR>',
        { desc = '[G]it [P]ush', silent = true, noremap = true }
      )
    end,
  },
  -- 'tpope/vim-rhubarb',
  {
    -- Adds git releated signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      -- See `:help gitsigns.txt`
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },
  -- https://github.com/pwntester/octo.nvim
  {
    'pwntester/octo.nvim',
    cmd = 'Octo',
    opts = {
      picker = 'snacks',
      -- bare Octo command opens picker of commands
      enable_builtin = true,
    },
    keys = {
      {
        '<leader>Oi',
        '<CMD>Octo issue list<CR>',
        desc = 'List GitHub Issues',
      },
      {
        '<leader>Op',
        '<CMD>Octo pr list<CR>',
        desc = 'List GitHub PullRequests',
      },
      {
        '<leader>Od',
        '<CMD>Octo discussion list<CR>',
        desc = 'List GitHub Discussions',
      },
      {
        '<leader>On',
        '<CMD>Octo notification list<CR>',
        desc = 'List GitHub Notifications',
      },
      {
        '<leader>Os',
        function()
          require('octo.utils').create_base_search_command({ include_current_repo = true })
        end,
        desc = 'Search GitHub',
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'folke/snacks.nvim',
      'nvim-tree/nvim-web-devicons',
    },
  },
}
