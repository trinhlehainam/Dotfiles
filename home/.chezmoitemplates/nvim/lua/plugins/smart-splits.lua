return {
  -- https://github.com/mrjones2014/smart-splits.nvim
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  config = function()
    require('smart-splits').setup()
    -- https://github.com/mrjones2014/smart-splits.nvim?tab=readme-ov-file#key-mappings
    -- recommended mappings
    -- resizing splits
    -- these keymaps will also accept a range,
    -- for example `10<A-,>` will `resize_left` by `(10 * config.default_amount)`
    vim.keymap.set('n', '<A-,>', require('smart-splits').resize_left)
    vim.keymap.set('n', '<A-.>', require('smart-splits').resize_right)
    vim.keymap.set('n', '<A-u>', require('smart-splits').resize_up)
    vim.keymap.set('n', '<A-d>', require('smart-splits').resize_down)
    -- moving between splits
    vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
    vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
    vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
    vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
  end,
}
