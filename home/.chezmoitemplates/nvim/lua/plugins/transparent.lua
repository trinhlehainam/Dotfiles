return {
  {
    'xiyaowong/nvim-transparent',
    config = function()
      require('transparent').setup({
        groups = { -- table: default groups
          'Normal',
          'NormalNC',
          'Comment',
          'Constant',
          'Special',
          'Identifier',
          'Statement',
          'PreProc',
          'Type',
          'Underlined',
          'Todo',
          'String',
          'Function',
          'Conditional',
          'Repeat',
          'Operator',
          'Structure',
          'LineNr',
          'NonText',
          'SignColumn',
          'CursorLineNr',
          'EndOfBuffer',
        },
        extra_groups = { -- table/string: additional groups that should be cleared
          -- In particular, when you set it to 'all', that means all available groups
        },
        exclude_groups = {}, -- table: groups you don't want to clear
      })
    end,
  },
}
