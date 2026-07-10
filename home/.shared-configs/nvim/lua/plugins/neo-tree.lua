--- @param state neotree.StateWithTree
--- @source https://github.com/nvim-neo-tree/neo-tree.nvim/blob/v3.x/doc/neo-tree.txt
local function copy_path(state)
  local node = state.tree:get_node()
  require('utils.copy_path').select(node and node.path)
end

return {
  -- https://github.com/nvim-neo-tree/neo-tree.nvim
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
    'folke/snacks.nvim',
  },
  lazy = true, -- Load neo-tree only when explicitly called via keybinding
  ---@module "neo-tree"
  ---@type neotree.Config?
  opts = {
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
        -- hide_by_name = {
        --   '.git',
        -- },
      },
    },
    window = {
      mappings = {
        -- https://github.com/GustavEikaas/easy-dotnet.nvim?tab=readme-ov-file#integrating-with-neo-tree
        -- Make the mapping anything you want
        ['R'] = 'easy',
        ['Y'] = copy_path,
      },
    },
    commands = {
      ['easy'] = function(state)
        local node = state.tree:get_node()
        local path = node.type == 'directory' and node.path or vim.fs.dirname(node.path)
        require('easy-dotnet').create_new_item(path, function()
          require('neo-tree.sources.manager').refresh(state.name)
        end)
      end,
    },
  },
  keys = {
    { '<leader>tt', '<cmd>Neotree<cr>', desc = '[T]oggle Neo[T]ree' },
    { '<A-,>', '<c-w>5<', ft = 'neo-tree' },
    { '<A-.>', '<c-w>5>', ft = 'neo-tree' },
  },
}
