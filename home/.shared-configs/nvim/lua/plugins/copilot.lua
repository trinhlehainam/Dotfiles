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
        ['opencode_terminal'] = false,
        ['neo-tree'] = false,
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

    --- Check if NES is available in current buffer.
    --- @return boolean
    local function has_nes()
      return vim.b[vim.api.nvim_get_current_buf()].nes_state ~= nil
    end

    --- Apply pending NES edit. Must be called from normal mode.
    --- Jumps to edit start first; if already there, applies and jumps to end.
    local function apply_nes()
      local ok, nes = pcall(require, 'copilot-lsp.nes')
      if not ok then
        return
      end
      if not nes.walk_cursor_start_edit() then
        if nes.apply_pending_nes() then
          nes.walk_cursor_end_edit()
        end
      end
    end

    -- Normal-mode: accept NES if pending
    vim.keymap.set('n', '<C-y>', function()
      if has_nes() then
        apply_nes()
      end
    end, { desc = 'Accept Copilot NES', silent = true })

    -- Insert-mode: accept suggestion or NES
    -- Priority: 1) inline suggestion  2) NES
    vim.keymap.set('i', '<C-y>', function()
      -- 1) Inline suggestion from copilot.lua
      local ok, suggestion = pcall(require, 'copilot.suggestion')
      if ok and suggestion.is_visible() then
        suggestion.accept()
        return
      end

      -- 2) NES from copilot-lsp (needs normal mode to apply)
      if has_nes() then
        vim.cmd('stopinsert')
        apply_nes()
      end
    end, { desc = 'Accept Copilot suggestion/NES', silent = true })
  end,
}
