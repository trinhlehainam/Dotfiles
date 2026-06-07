---@diagnostic disable: undefined-global
local M = {}

---@param bufname string
---@return string
local function start_dir_from_bufname(bufname)
  if bufname == '' or bufname:match('^%a[%w+.-]*://') then
    return vim.fn.getcwd()
  end

  local ok, dir = pcall(vim.fs.dirname, bufname)
  return (ok and dir) or vim.fn.getcwd()
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

  local obsidian_dir = obsidian_dirs[1]
  if not obsidian_dir then
    return nil
  end

  return vim.fs.dirname(obsidian_dir)
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
