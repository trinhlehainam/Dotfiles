-- ============================================================================
-- VIM-TMUX-NAVIGATOR PLUGIN CONFIGURATION
-- ============================================================================
--
-- Seamless navigation between Vim splits and tmux panes using consistent
-- Ctrl-h/j/k/l keybindings. This plugin enables intelligent window switching
-- that works across the Vim/tmux boundary.
--
-- Key Features:
-- - Unified navigation: Same keys work in both Vim and tmux
-- - Smart detection: Automatically determines if movement should be in Vim or tmux
-- - Terminal support: Works seamlessly with Neovim terminal buffers
-- - Lazy loading: Only loads when navigation commands are used
--
-- Integration with keymaps.lua:
-- - Normal mode: Ctrl-h/j/k/l keys defined here
-- - Terminal mode: Additional mappings in keymaps.lua (see set_terminal_keymaps)
-- - The terminal mappings check vim.g.loaded_tmux_navigator to provide fallback
--
-- Required tmux configuration:
-- Add to ~/.tmux.conf:
-- ```
-- # Smart pane switching with awareness of Vim splits
-- is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
--     | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
-- bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
-- bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
-- bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
-- bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
-- ```
--
-- References:
-- - Plugin: https://github.com/christoomey/vim-tmux-navigator
-- - Lazy.nvim config: https://github.com/christoomey/vim-tmux-navigator?tab=readme-ov-file#lazynvim
--
-- ============================================================================

return {
  'christoomey/vim-tmux-navigator',
  -- Lazy load on these commands for faster startup
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    -- 'TmuxNavigatePrevious', -- Uncomment if you want Ctrl-\ for previous pane
    'TmuxNavigatorProcessList',
  },
  init = function()
    -- Disable default mappings - we define our own in the 'keys' section below
    -- This gives us full control over the keybindings and lazy loading behavior
    -- Reference: https://github.com/christoomey/vim-tmux-navigator?tab=readme-ov-file#vim-1
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    -- Define navigation keybindings for normal mode
    -- These will trigger lazy loading of the plugin when first used
    -- Format: { key, command, description (optional) }
    { '<c-h>', '<cmd>TmuxNavigateLeft<cr>', desc = 'Navigate to left pane/split' },
    { '<c-j>', '<cmd>TmuxNavigateDown<cr>', desc = 'Navigate to pane/split below' },
    { '<c-k>', '<cmd>TmuxNavigateUp<cr>', desc = 'Navigate to pane/split above' },
    { '<c-l>', '<cmd>TmuxNavigateRight<cr>', desc = 'Navigate to right pane/split' },
  },
}
