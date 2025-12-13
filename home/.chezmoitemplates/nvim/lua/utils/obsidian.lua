---@diagnostic disable: undefined-global
local M = {}

---@param bufname string
---@return string
local function start_dir_from_bufname(bufname)
  return (bufname ~= '' and vim.fs.dirname(bufname)) or vim.fn.getcwd()
end

---@param bufname string
---@return string|nil
function M.vault_root_from_bufname(bufname)
  local start_dir = start_dir_from_bufname(bufname)

  local obsidian_dirs = vim.fs.find('.obsidian', {
    path = start_dir,
    upward = true,
    type = 'directory',
    limit = 1,
  })

  local _, obsidian_dir = next(obsidian_dirs)
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

---@param bufnr? integer
---@return string|nil
function M.vault_root(bufnr)
  bufnr = bufnr or 0
  return M.vault_root_from_bufname(vim.api.nvim_buf_get_name(bufnr))
end

---@param bufnr? integer
---@return boolean
function M.is_vault(bufnr)
  return M.vault_root(bufnr) ~= nil
end

return M
