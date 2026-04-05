return {
  -- https://github.com/folke/todo-comments.nvim
  -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#todo_comments
  'folke/todo-comments.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'folke/snacks.nvim',
  },
  opts = {},
  keys = {
    {
      '<leader>st',
      function()
        Snacks.picker.todo_comments()
      end,
      desc = 'Todo',
    },
    {
      '<leader>sT',
      function()
        Snacks.picker.todo_comments({ keywords = { 'TODO', 'FIX', 'FIXME' } })
      end,
      desc = 'Todo/Fix/Fixme',
    },
  },
}
