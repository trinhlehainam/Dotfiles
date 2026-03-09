local log = require('utils.log')

local M = {}

local ROOT_MARKERS = { '.git', '.jj', '.nvim', '.vscode' }
local cache = {}

local function cache_key(root, relpath)
  return root .. '\0' .. relpath
end

local function read_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end

  local data = file:read('*a')
  file:close()
  return data
end

---@param bufnr? integer
---@return string|nil
function M.find_root(bufnr)
  bufnr = bufnr or 0

  local ok, root = pcall(vim.fs.root, bufnr, ROOT_MARKERS)
  if ok then
    return root
  end

  return nil
end

---@param root string
---@param relpath string
---@return table
function M.read_json(root, relpath)
  local key = cache_key(root, relpath)
  if cache[key] ~= nil then
    return vim.deepcopy(cache[key])
  end

  local path = root .. '/' .. relpath
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    cache[key] = {}
    return {}
  end

  local raw = read_file(path)
  if raw == nil then
    log.warn(('Could not read %s'):format(path), 'project-json')
    cache[key] = {}
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok then
    log.warn(('Invalid JSON in %s: %s'):format(path, tostring(decoded)), 'project-json')
    cache[key] = {}
    return {}
  end

  if type(decoded) ~= 'table' then
    log.warn(('Expected JSON object in %s'):format(path), 'project-json')
    cache[key] = {}
    return {}
  end

  cache[key] = decoded
  return vim.deepcopy(decoded)
end

---@param root? string
function M.invalidate(root)
  if not root then
    cache = {}
    return
  end

  local prefix = root .. '\0'
  for key in pairs(cache) do
    if key:sub(1, #prefix) == prefix then
      cache[key] = nil
    end
  end
end

return M
