return {
  'zbirenbaum/copilot.lua',
  dependencies = {
    {
      'copilotlsp-nvim/copilot-lsp',
      init = function()
        vim.g.copilot_nes_debounce = 500
      end,
    },
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
          accept = false,
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

      filetypes = {
        ['*'] = true,
        ['opencode-terminal'] = false,
        sh = function()
          if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), '^%.env.*') then
            return false
          end
          return true
        end,
      },
    })

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

    vim.keymap.set('n', '<leader>tc', function()
      require('copilot.suggestion').toggle_auto_trigger()
    end, { desc = '[T]oggle [C]opilot suggestions' })

    -- Normal-mode: keep a dedicated key for NES acceptance.
    -- If there's an NES pending, accept/apply it; otherwise preserve the default
    -- `<C-y>` behavior (scroll up).
    vim.keymap.set('n', '<C-y>', function()
      local bufnr = vim.api.nvim_get_current_buf()
      local nes_ok, nes = pcall(require, 'copilot-lsp.nes')

      if nes_ok and vim.b[bufnr].nes_state then
        local _ = nes.walk_cursor_start_edit()
          or (nes.apply_pending_nes() and nes.walk_cursor_end_edit())
        return ''
      end

      return '<C-i>'
    end, { desc = 'Accept Copilot NES (fallback: <C-y>)', expr = true, silent = true })

    -- One key to accept "the thing Copilot is offering".
    -- Priority:
    --   1) `copilot.lua` inline suggestion (ghost text)
    --   2) `copilot-lsp` NES (next edit suggestion)
    --   3) fallback to default <C-y>
    vim.keymap.set('i', '<C-y>', function()
      local suggestion_ok, suggestion = pcall(require, 'copilot.suggestion')
      if suggestion_ok and suggestion.is_visible() then
        suggestion.accept()
        return
      end

      local bufnr = vim.api.nvim_get_current_buf()
      local nes_ok, nes = pcall(require, 'copilot-lsp.nes')
      if nes_ok and vim.b[bufnr].nes_state then
        -- NES is applied from normal-mode; briefly exit insert-mode, apply,
        -- then return to insert-mode.
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
          'n',
          false
        )
        vim.schedule(function()
          nes.walk_cursor_start_edit()
          if nes.apply_pending_nes() then
            nes.walk_cursor_end_edit()
          end
          vim.cmd('startinsert')
        end)
        return
      end

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-y>', true, false, true), 'n', false)
    end, { desc = 'Accept Copilot suggestion/NES', silent = true })
  end,
}
