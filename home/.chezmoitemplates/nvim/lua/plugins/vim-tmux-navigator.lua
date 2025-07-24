return {
  -- NOTE: https://github.com/christoomey/vim-tmux-navigator?tab=readme-ov-file#lazynvim
  'christoomey/vim-tmux-navigator',
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    -- 'TmuxNavigatePrevious',
    'TmuxNavigatorProcessList',
  },
  init = function()
    -- https://lazy.folke.io/spec#spec-setup
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    -- Normal mode mappings (default)
    { '<c-h>', '<cmd>TmuxNavigateLeft<cr>' },
    { '<c-j>', '<cmd>TmuxNavigateDown<cr>' },
    { '<c-k>', '<cmd>TmuxNavigateUp<cr>' },
    { '<c-l>', '<cmd>TmuxNavigateRight<cr>' },
  },
}
