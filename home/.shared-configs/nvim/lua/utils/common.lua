local M = {}

local uname = vim.uv.os_uname()
local release = (uname.release or ''):lower()

M.OS = uname.sysname
M.IS_MAC = M.OS == 'Darwin'
M.IS_LINUX = M.OS == 'Linux'
M.IS_WINDOWS = M.OS:find('Windows') ~= nil
M.IS_WSL = M.IS_LINUX and (release:find('microsoft') ~= nil or release:find('wsl') ~= nil)

---@param mode string|string[]
---@param bufnr number
---@param prefix? string
---@param opts? vim.keymap.set.Opts
---@return fun(keys: string, func: function|string, desc?: string)
function M.create_map(mode, bufnr, prefix, opts)
  return function(keys, func, desc)
    local map_opts = vim.tbl_extend('force', opts or {}, {
      buffer = bufnr,
      desc = (prefix ~= nil and prefix ~= '' and desc) and (prefix .. ': ' .. desc) or desc,
    })

    vim.keymap.set(mode, keys, func, map_opts)
  end
end

---@param bufnr number
---@param prefix? string
---@param opts? vim.keymap.set.Opts
---@return fun(keys: string, func: function|string, desc?: string)
function M.create_nmap(bufnr, prefix, opts)
  return M.create_map('n', bufnr, prefix or 'LSP', opts)
end

---@param bufnr number
---@param prefix? string
---@param opts? vim.keymap.set.Opts
---@return fun(keys: string, func: function|string, desc?: string)
function M.create_vmap(bufnr, prefix, opts)
  return M.create_map('v', bufnr, prefix or 'LSP', opts)
end

---@param base? string[]
---@param extra? string[]
---@return string[]
function M.merge_unique_strings(base, extra)
  local merged = vim.deepcopy(base or {})
  local seen = {}

  for _, value in ipairs(merged) do
    seen[value] = true
  end

  for _, value in ipairs(extra or {}) do
    if type(value) == 'string' and value ~= '' and not seen[value] then
      seen[value] = true
      table.insert(merged, value)
    end
  end

  return merged
end

---@param tbl table|nil
---@return string[]
function M.sorted_keys(tbl)
  local keys = vim.tbl_keys(tbl or {})
  table.sort(keys)
  return keys
end

---@param extension? string
---@return string
function M.create_temp_file(extension)
  local temp_file = vim.fn.tempname()

  if not extension or extension == '' then
    return temp_file
  end

  -- `tempname()`/`os.tmpname()` typically only returns a path. Avoid rename() because
  -- the file may not exist yet.
  return temp_file .. '.' .. extension
end

return M
