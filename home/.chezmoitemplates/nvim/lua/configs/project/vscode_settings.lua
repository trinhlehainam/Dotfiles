local log = require('utils.log')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'

---@type table<string, table>
local settings_cache = {}
local warned_missing_codesettings = false

---@param path string
---@return string|nil
local function read_text_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end

  local data = file:read('*a')
  file:close()
  return data
end

---@param root string
---@return table
local function load_settings(root)
  if settings_cache[root] ~= nil then
    return settings_cache[root]
  end

  local path = root .. '/' .. VSCODE_SETTINGS
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    settings_cache[root] = {}
    return settings_cache[root]
  end

  local raw = read_text_file(path)
  if raw == nil then
    log.warn(('Could not read %s'):format(path), TITLE)
    settings_cache[root] = {}
    return settings_cache[root]
  end

  local ok_codesettings, codesettings_util = pcall(require, 'codesettings.util')
  if not ok_codesettings then
    if not warned_missing_codesettings then
      warned_missing_codesettings = true
      log.warn(
        ('codesettings.nvim is unavailable; %s project settings will be ignored'):format(
          VSCODE_SETTINGS
        ),
        TITLE
      )
    end
    return {}
  end

  local ok_settings, settings = pcall(function()
    -- Use the lower-level JSONC decoder instead of `local_settings()`: the
    -- higher-level Settings loader expands dotted keys like `files.associations`
    -- into nested tables, which breaks glob keys such as `*.templ`.
    return codesettings_util.json_decode(raw)
  end)

  if not ok_settings then
    log.warn(('Invalid JSON in %s: %s'):format(path, tostring(settings)), TITLE)
    settings_cache[root] = {}
    return settings_cache[root]
  end

  settings_cache[root] = type(settings) == 'table' and settings or {}
  return settings_cache[root]
end

---@param root string
---@return table
function M.read(root)
  if type(root) ~= 'string' or root == '' then
    return {}
  end

  return vim.deepcopy(load_settings(root))
end

---@param root? string
function M.invalidate(root)
  if not root then
    settings_cache = {}
    return
  end

  settings_cache[root] = nil
end

return M
