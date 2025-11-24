--- @param state neotree.StateWithTree
--- @see https://github.com/nvim-neo-tree/neo-tree.nvim/discussions/370#discussioncomment-8303412
--- @see https://github.com/nvim-neo-tree/neo-tree.nvim/discussions/370#discussioncomment-14442475
local function copy_path(state)
  -- NeoTree is based on [NuiTree](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/tree)
  -- The node is based on [NuiNode](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/tree#nuitreenode)
  local node = state.tree:get_node()
  if not node or not node.id then
    vim.notify('No node selected.', vim.log.levels.WARN)
    return
  end

  if vim.fn.has('clipboard') == 0 then
    vim.notify('System clipboard is not available.', vim.log.levels.ERROR)
    return
  end

  local filepath = node:get_id()
  local filename = node.name
  local modify = vim.fn.fnamemodify

  local choices = {
    { label = 'Absolute path', value = filepath },
    { label = 'Path relative to CWD', value = modify(filepath, ':.') },
    { label = 'Path relative to HOME', value = modify(filepath, ':~') },
    { label = 'Filename', value = filename },
    { label = 'Filename without extension', value = modify(filename, ':r') },
    { label = 'Extension of the filename', value = modify(filename, ':e') },
  }

  require('snacks').picker.select(choices, {
    prompt = 'Choose to copy to clipboard:',
    format_item = function(item)
      return string.format('%-30s %s', item.label, item.value)
    end,
  }, function(choice)
    if not choice then
      vim.notify('Copy cancelled.', vim.log.levels.INFO)
      return
    end

    local value_to_copy = choice.value

    vim.fn.setreg('+', value_to_copy)
    vim.notify('Copied to clipboard: ' .. value_to_copy)
  end)
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
