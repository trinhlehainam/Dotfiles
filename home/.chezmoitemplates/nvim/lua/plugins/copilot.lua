return {
  'zbirenbaum/copilot.lua',
  dependencies = {
    'copilotlsp-nvim/copilot-lsp',
    init = function()
      vim.g.copilot_nes_debounce = 500
    end,
  },
  cmd = 'Copilot',
  event = 'InsertEnter',
  config = function()
    -- https://github.com/zbirenbaum/copilot.lua?tab=readme-ov-file#setup-and-configuration
    require('copilot').setup({
      panel = {
        enabled = false,
      },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = '<C-y>',
          next = '<C-n>',
          prev = '<C-p>',
        },
      },
      nes = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          dismiss = '<Esc>',
        },
      },

      -- Filetype configuration
      filetypes = {
        ['*'] = true,
        -- Disable for sensitive files like .env
        sh = function()
          if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), '^%.env.*') then
            return false
          end
          return true
        end,
      },
    })

    -- Hide copilot suggestions when blink.cmp menu is open
    vim.api.nvim_create_autocmd('User', {
      pattern = 'BlinkCmpMenuOpen',
      callback = function()
        vim.b.copilot_suggestion_hidden = true
      end,
    })

    vim.api.nvim_create_autocmd('User', {
      pattern = 'BlinkCmpMenuClose',
      callback = function()
        vim.b.copilot_suggestion_hidden = false
      end,
    })

    -- Toggle Copilot suggestions
    vim.keymap.set('n', '<leader>tc', function()
      require('copilot.suggestion').toggle_auto_trigger()
    end, { desc = '[T]oggle [C]opilot suggestions' })

    vim.keymap.set({ 'n' }, '<C-y>', function()
      local bufnr = vim.api.nvim_get_current_buf()
      local state = vim.b[bufnr].nes_state
      if state then
        -- Try to jump to the start of the suggestion edit.
        -- If already at the start, then apply the pending suggestion and jump to the end of the edit.
        local _ = require('copilot-lsp.nes').walk_cursor_start_edit()
          or (
            require('copilot-lsp.nes').apply_pending_nes()
            and require('copilot-lsp.nes').walk_cursor_end_edit()
          )
        return nil
      else
        -- Resolving the terminal's inability to distinguish between `TAB` and `<C-i>` in normal mode
        return '<C-i>'
      end
    end, { desc = 'Accept Copilot NES suggestion', expr = true })
  end,
}
