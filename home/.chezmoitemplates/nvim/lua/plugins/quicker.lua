return {
  --- https://github.com/stevearc/quicker.nvim
  'stevearc/quicker.nvim',
  ft = 'qf',
  ---@module "quicker"
  ---@type quicker.SetupOptions
  opts = {
    keys = {
      {
        '>',
        function()
          require('quicker').expand({ before = 2, after = 2, add_to_existing = true })
        end,
        desc = 'Expand quickfix context',
      },
      {
        '<',
        function()
          require('quicker').collapse()
        end,
        desc = 'Collapse quickfix context',
      },
    },
  },
  keys = {
    {
      '<leader>qf',
      function()
        require('quicker').toggle()
      end,
      desc = 'Toggle quickfix',
    },
    {
      '<leader>lo',
      function()
        require('quicker').toggle({ loclist = true })
      end,
      desc = 'Toggle loclist',
    },
  },
}
