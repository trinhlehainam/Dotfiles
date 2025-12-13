local obsidian = require('utils.obsidian')

local function is_vault()
  return obsidian.is_vault(0)
end

return {
  'obsidian-nvim/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  ft = 'markdown',
  cond = is_vault,
  --- https://github.com/obsidian-nvim/obsidian.nvim/blob/main/lua/obsidian/config/default.lua
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- this will be removed in the next major release
    ui = { enable = false }, -- avoid conflict with render-markdown.nvim
    disable_frontmatter = true,
    workspaces = {
      {
        name = vim.fs.basename(obsidian.vault_root(0) or vim.fn.getcwd()) or 'dynamic',
        path = function()
          return obsidian.vault_root(0) or vim.fn.getcwd()
        end,
      },
    },
    picker = {
      name = 'snacks.pick',
    },
    attachments = {},
  },
  keys = {
    {
      '<leader>sf',
      function()
        if not is_vault() then
          return
        end
        vim.cmd('Obsidian quick_switch')
      end,
      desc = 'Obsidian: Quick switch',
    },
    {
      '<leader>sg',
      function()
        if not is_vault() then
          return
        end
        vim.cmd('Obsidian search')
      end,
      desc = 'Obsidian: Grep notes',
    },
  },
}
