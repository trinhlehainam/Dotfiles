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
        name = 'dynamic',
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
}
