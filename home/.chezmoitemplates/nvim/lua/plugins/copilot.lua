return {
  'zbirenbaum/copilot.lua',
  dependencies = {
    'copilotlsp-nvim/copilot-lsp', -- (optional) for NES functionality
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
        keymap = {
          accept = '<A-y>',
          next = '<A-n>',
          prev = '<A-p>',
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
    vim.keymap.set('n', '<leader>cc', function()
      require('copilot.suggestion').toggle_auto_trigger()
    end, { desc = '[C]opilot toggle suggestions' })
  end,
}
