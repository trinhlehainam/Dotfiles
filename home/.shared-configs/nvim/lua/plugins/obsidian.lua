local obsidian = require('utils.obsidian')

---@param note obsidian.Note
local function set_note_keymaps(note)
  local bufnr = assert(note.bufnr)

  vim.keymap.set('n', '<leader>sf', '<cmd>Obsidian quick_switch<cr>', {
    buffer = bufnr,
    desc = 'Obsidian: Quick switch',
  })
  vim.keymap.set('n', '<leader>sg', '<cmd>Obsidian search<cr>', {
    buffer = bufnr,
    desc = 'Obsidian: Grep notes',
  })
end

return {
  'obsidian-nvim/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  lazy = true,
  init = function()
    vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
      pattern = '*.md',
      callback = function(args)
        if obsidian.is_vault(args.buf) then
          require('lazy').load({ plugins = { 'obsidian.nvim' } })
          return true
        end
      end,
    })
  end,
  --- https://github.com/obsidian-nvim/obsidian.nvim/wiki
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- will be removed in 4.0.0
    ui = { enable = false }, -- avoid conflict with render-markdown.nvim
    frontmatter = {
      enabled = false,
    },
    footer = {
      enabled = false,
    },
    workspaces = {
      {
        name = 'dynamic',
        path = function()
          return assert(obsidian.vault_root(0), 'Obsidian vault root not found')
        end,
      },
    },
    picker = {
      name = 'snacks.picker',
    },
    callbacks = {
      enter_note = set_note_keymaps,
    },
  },
}
