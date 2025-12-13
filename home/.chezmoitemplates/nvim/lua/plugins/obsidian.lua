--- Find the Obsidian vault root for the current buffer.
---
--- The vault root is identified by traversing upward from the current buffer's
--- directory until a `.obsidian/` directory is found.
---
--- For stricter gating, also require a workspace config file to exist.
---@return string|nil
local function obsidian_vault_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  local start_dir = (bufname ~= '' and vim.fs.dirname(bufname)) or vim.fn.getcwd()

  local obsidian_dirs = vim.fs.find('.obsidian', {
    path = start_dir,
    upward = true,
    type = 'directory',
  })
  local obsidian_dir = obsidian_dirs[1]
  if not obsidian_dir then
    return nil
  end

  local vault_root = vim.fs.dirname(obsidian_dir)
  if not vault_root then
    return nil
  end

  local has_workspace = vim.fn.filereadable(vault_root .. '/.obsidian/workspace.json') == 1
    or vim.fn.filereadable(vault_root .. '/.obsidian/workspace-mobile.json') == 1

  return has_workspace and vault_root or nil
end

---@return boolean
local function is_obsidian_vault()
  return obsidian_vault_root() ~= nil
end

return {
  'obsidian-nvim/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  ft = 'markdown',
  cond = is_obsidian_vault,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- this will be removed in the next major release
    disable_frontmatter = true,
    workspaces = {
      {
        name = 'dynamic',
        path = function()
          return obsidian_vault_root() or vim.fn.getcwd()
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
