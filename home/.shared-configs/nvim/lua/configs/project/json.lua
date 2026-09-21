local buffer_utils = require('utils.buffer')
local log = require('utils.log')

local M = {}

-- Shared reader for project-local JSON files. Root detection walks upward from
-- a file or directory until it finds a project marker, then JSON payloads are
-- cached per `<root, relpath>` to avoid repeated disk reads during buffer events.

local TITLE = 'project-json'
local ROOT_MARKERS = { '.git', '.jj', '.nvim', '.vscode' }

---@type table<string, table>
local json_cache = {}

---@param root string
---@param relpath string
---@return string
local function cache_key(root, relpath)
  return root .. '\0' .. relpath
end

---@param path string
---@return string|nil
function M.read_text_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end

  local data = file:read('*a')
  file:close()
  return data
end

---@param path string
---@return string|nil
local function find_root_from_path(path)
  if type(path) ~= 'string' or path == '' then
    return nil
  end

  -- A predicate gives all markers equal priority across Neovim versions.
  return vim.fs.root(path, function(name)
    return vim.tbl_contains(ROOT_MARKERS, name)
  end)
end

---@param path string
---@return table
local function decode_json_file(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return {}
  end

  local raw = M.read_text_file(path)
  if raw == nil then
    log.warn(('Could not read %s'):format(path), TITLE)
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok then
    log.warn(('Invalid JSON in %s: %s'):format(path, tostring(decoded)), TITLE)
    return {}
  end

  if type(decoded) ~= 'table' then
    log.warn(('Expected JSON object in %s'):format(path), TITLE)
    return {}
  end

  return decoded
end

---@param path string
---@return string|nil
function M.find_root_for_path(path)
  return find_root_from_path(path)
end

---@param bufnr? integer
---@return string|nil
function M.find_root(bufnr)
  bufnr = bufnr or 0

  local name = buffer_utils.name(bufnr)
  if name ~= '' then
    return find_root_from_path(name)
  end

  return find_root_from_path(vim.uv.cwd() or vim.fn.getcwd())
end

---@param root string
---@param relpath string
---@return table
function M.read_json(root, relpath)
  local key = cache_key(root, relpath)
  if json_cache[key] == nil then
    json_cache[key] = decode_json_file(root .. '/' .. relpath)
  end

  return vim.deepcopy(json_cache[key])
end

---@param root? string
function M.invalidate(root)
  if not root then
    json_cache = {}
    return
  end

  local prefix = root .. '\0'
  for key in pairs(json_cache) do
    if key:sub(1, #prefix) == prefix then
      json_cache[key] = nil
    end
  end
end

return M
