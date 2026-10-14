return {
  -- https://github.com/smart-splits-nvim/smart-splits.nvim#backends
  'smart-splits-nvim/smart-splits.nvim',
  version = '^3.0.0',
  -- The tmux backend must mark the pane before tmux can forward navigation keys.
  lazy = false,
  dependencies = {
    { 'smart-splits-nvim/backend-tmux', main = 'smart-splits-backend-tmux' },
    { 'smart-splits-nvim/backend-wezterm', main = 'smart-splits-backend-wezterm' },
  },
  opts = {
    mux = {
      -- tmux is the inner multiplexer when it runs inside WezTerm.
      backend = { 'smart-splits-backend-tmux', 'smart-splits-backend-wezterm' },
      warn_if_unusable = false, -- Plain terminals still support Neovim splits.
    },
  },
  config = function(_, opts)
    local smart_splits = require('smart-splits')
    smart_splits.setup(opts)

    -- Counts multiply resize.amount (3 cells by default), e.g. 10<A-,> resizes by 30.
    vim.keymap.set('n', '<A-,>', smart_splits.resize_left)
    vim.keymap.set('n', '<A-.>', smart_splits.resize_right)
    vim.keymap.set('n', '<A-u>', smart_splits.resize_up)
    vim.keymap.set('n', '<A-d>', smart_splits.resize_down)
    -- Move through Neovim windows, then into the selected multiplexer.
    vim.keymap.set('n', '<C-h>', smart_splits.move_cursor_left)
    vim.keymap.set('n', '<C-j>', smart_splits.move_cursor_down)
    vim.keymap.set('n', '<C-k>', smart_splits.move_cursor_up)
    vim.keymap.set('n', '<C-l>', smart_splits.move_cursor_right)
  end,
}
