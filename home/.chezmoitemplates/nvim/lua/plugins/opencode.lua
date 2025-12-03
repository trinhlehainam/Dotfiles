return {
  'NickvanDyke/opencode.nvim',
  dependencies = {
    -- Recommended for `ask()` and `select()`.
    -- Required for `snacks` provider.
    ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
    { 'folke/snacks.nvim', opts = { input = {}, picker = {}, terminal = {} } },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
    }

    -- Required for `opts.events.reload`.
    vim.o.autoread = true

    vim.keymap.set({ 'n', 'x' }, '<leader>oa', function()
      require('opencode').ask('@this: ', { submit = true })
    end, { desc = 'Ask opencode' })
    vim.keymap.set({ 'n', 'x' }, '<leader>ox', function()
      require('opencode').select()
    end, { desc = 'Execute opencode action…' })
    vim.keymap.set({ 'n', 'x' }, '<leader>os', function()
      require('opencode').prompt('@this')
    end, { desc = 'Send to opencode' })
    vim.keymap.set({ 'n', 'x' }, '<leader>ob', function()
      require('opencode').prompt('@buffer')
    end, { desc = 'Add current buffer' })
    vim.keymap.set({ 'n', 't' }, '<leader>oc', function()
      require('opencode').toggle()
    end, { desc = 'Toggle opencode' })
  end,
}
