return {
  {
    'rbong/vim-flog',
    dependencies = {
      'tpope/vim-fugitive',
    }
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

  {
    'sindrets/diffview.nvim',
    config = function()
      local actions = require('diffview.actions')
      require('diffview').setup {
        keymaps = {
          file_panel = {
            { "n", "j", false },
            { "n", ";", false },
            { "n", "k", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
            { "n", "l", actions.prev_entry, { desc = "Bring the cursor to the previous file entry" } },
          }
        }
      }
    end
  },

  -- Github related plugins
  {
    'pwntester/octo.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    config = function()
      require('octo').setup {}
    end
  },
}
