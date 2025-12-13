local obsidian = require('utils.obsidian')

return {
  'obsidian-nvim/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  ft = 'markdown',
  cond = function()
    return obsidian.is_vault(0)
  end,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- this will be removed in the next major release
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
    completion = {},
    attachments = {
      img_folder = 'Files',
    },
  },
  keys = {
    {
      '<leader>sf',
      function()
        if not obsidian.is_vault(0) then
          return
        end
        vim.cmd('Obsidian quick_switch')
      end,
      desc = 'Obsidian: Quick switch',
    },
    {
      '<leader>sg',
      function()
        if not obsidian.is_vault(0) then
          return
        end
        vim.cmd('Obsidian search')
      end,
      desc = 'Obsidian: Grep notes',
    },
  },
}
