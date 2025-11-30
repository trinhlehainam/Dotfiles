local M = {}

M.setup = function()
  local noice = require('noice')
  noice.setup({
    lsp = {
      -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
      override = {
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true, -- requires hrsh7th/nvim-cmp
      },
    },
    -- you can enable a preset for easier configuration
    presets = {
      bottom_search = false, -- use a classic bottom cmdline for search
      command_palette = true, -- position the cmdline and popupmenu together
      long_message_to_split = true, -- long messages will be sent to a split
      inc_rename = false, -- enables an input dialog for inc-rename.nvim
      lsp_doc_border = true, -- add a border to hover docs and signature help
    },
  })

  vim.keymap.set('n', '<leader>np', function()
    noice.cmd('pick')
  end, { desc = '[N]oice Picker (His[t]ory)' })

  vim.keymap.set('n', '<leader>nh', function()
    noice.cmd('pick')
  end, { desc = '[N]oice [H]istory' })

  vim.keymap.set('n', '<leader>nd', function()
    noice.cmd('dismiss')
  end, { desc = '[N]oice [D]ismiss' })
end

M.parsers = { 'vim', 'regex', 'lua', 'bash', 'markdown', 'markdown_inline' }

return M
