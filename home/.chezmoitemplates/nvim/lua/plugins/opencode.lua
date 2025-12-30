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
    vim.g.opencode_opts = {}

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

    -- Passthrough <C-A-d> and <C-A-u> to OpenCode terminal
    -- These are used for half-page scrolling in OpenCode
    -- Must use nvim_chan_send() to write directly to terminal PTY,
    -- bypassing Neovim's input processing
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'opencode_terminal',
      callback = function(args)
        local bufnr = args.buf
        local opts = { buffer = bufnr, silent = true }

        local function send_to_terminal(escape_seq)
          local chan = vim.bo[bufnr].channel
          if chan then
            vim.api.nvim_chan_send(chan, escape_seq)
          end
        end

        -- ESC + Ctrl-D (0x1b 0x04) for Ctrl-Alt-D
        vim.keymap.set('t', '<C-A-d>', function()
          send_to_terminal('\x1b\x04')
        end, opts)

        -- ESC + Ctrl-U (0x1b 0x15) for Ctrl-Alt-U
        vim.keymap.set('t', '<C-A-u>', function()
          send_to_terminal('\x1b\x15')
        end, opts)

        -- Ctrl-W (0x17) for delete word backward
        -- Bypasses Neovim's window command prefix
        vim.keymap.set('t', '<C-w>', function()
          send_to_terminal('\x17')
        end, opts)
      end,
    })
  end,
}
