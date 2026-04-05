return {
  -- https://github.com/mrjones2014/smart-splits.nvim
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  config = function()
    -- WezTerm user var used by WezTerm config/keybindings to detect when
    -- the foreground program is Neovim.
    -- Reference (OSC 1337 `SetUserVar` / `__wezterm_set_user_var`):
    -- https://wezterm.org/config/lua/pane/get_user_vars.html
    local common = require('utils.common')

    local wezterm_group = vim.api.nvim_create_augroup('wezterm_user_vars', { clear = true })
    vim.api.nvim_create_autocmd('VimEnter', {
      group = wezterm_group,
      callback = function()
        common.wezterm_set_user_var('IS_NVIM', 'true')
      end,
    })

    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = wezterm_group,
      callback = function()
        common.wezterm_set_user_var('IS_NVIM', '')
      end,
    })

    require('smart-splits.api')
    local smart_splits = require('smart-splits')
    -- https://github.com/mrjones2014/smart-splits.nvim?tab=readme-ov-file#configuration
    smart_splits.setup({})
    -- https://github.com/mrjones2014/smart-splits.nvim?tab=readme-ov-file#key-mappings
    -- recommended mappings
    -- resizing splits
    -- these keymaps will also accept a range,
    -- for example `10<A-,>` will `resize_left` by `(10 * config.default_amount)`
    vim.keymap.set('n', '<A-,>', smart_splits.resize_left)
    vim.keymap.set('n', '<A-.>', smart_splits.resize_right)
    vim.keymap.set('n', '<A-u>', smart_splits.resize_up)
    vim.keymap.set('n', '<A-d>', smart_splits.resize_down)
    -- moving between splits
    vim.keymap.set('n', '<C-h>', smart_splits.move_cursor_left)
    vim.keymap.set('n', '<C-j>', smart_splits.move_cursor_down)
    vim.keymap.set('n', '<C-k>', smart_splits.move_cursor_up)
    vim.keymap.set('n', '<C-l>', smart_splits.move_cursor_right)
  end,
}
