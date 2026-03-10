require('configs.project.types')

local buffer_utils = require('utils.buffer')
local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'

---@type table<string, ProjectFiletypeSettingsMap>
local filetype_settings_cache = {}

---@param key string
local function warn_ignored(key)
  log.warn(('Ignored unsupported key "%s" in %s'):format(key, VSCODE_SETTINGS), TITLE)
end

---@param filetype string
---@return string[]
local function expand_filetype_keys(filetype)
  if type(filetype) ~= 'string' or filetype == '' then
    return {}
  end

  local keys = {}
  local seen = {}

  for _, part in ipairs(vim.split(filetype, '.', { plain = true })) do
    if part ~= '' and not seen[part] then
      seen[part] = true
      table.insert(keys, part)
    end
  end

  if not seen[filetype] then
    table.insert(keys, filetype)
  end

  return keys
end

---@param filetype_settings ProjectFiletypeSettingsMap
---@param filetype string
---@return ProjectFiletypeSettings
local function merge_filetype_settings(filetype_settings, filetype)
  local merged = {}

  for _, key in ipairs(expand_filetype_keys(filetype)) do
    merged = vim.tbl_extend('force', merged, filetype_settings[key] or {})
  end

  return merged
end

---@param key string
---@param raw any
---@param filetype_settings ProjectFiletypeSettingsMap
local function parse_filetype_settings_block(key, raw, filetype_settings)
  if type(raw) ~= 'table' then
    warn_ignored(key)
    return
  end

  local filetypes = {}
  for filetype in key:gmatch('%[([^%]]+)%]') do
    table.insert(filetypes, filetype)
  end

  if #filetypes == 0 then
    warn_ignored(key)
    return
  end

  local settings = {}
  for _, nested_key in ipairs(common.sorted_keys(raw)) do
    local value = raw[nested_key]

    if nested_key == 'editor.insertSpaces' and type(value) == 'boolean' then
      settings.insert_spaces = value
    elseif nested_key == 'editor.tabSize' and type(value) == 'number' then
      settings.tab_size = value
    elseif nested_key == 'editor.detectIndentation' and type(value) == 'boolean' then
      settings.detect_indentation = value
    elseif nested_key == 'editor.formatOnSave' and type(value) == 'boolean' then
      settings.format_on_save = value
    else
      warn_ignored(('%s.%s'):format(key, nested_key))
    end
  end

  for _, filetype in ipairs(filetypes) do
    filetype_settings[filetype] =
      vim.tbl_extend('force', filetype_settings[filetype] or {}, settings)
  end
end

---@param root string
---@return ProjectFiletypeSettingsMap
local function load_filetype_settings(root)
  if filetype_settings_cache[root] then
    return filetype_settings_cache[root]
  end

  local raw = project_json.read_json(root, VSCODE_SETTINGS)
  local filetype_settings = {}

  for _, key in ipairs(common.sorted_keys(raw)) do
    if key:match('^%[.+%]$') then
      parse_filetype_settings_block(key, raw[key], filetype_settings)
    end
  end

  filetype_settings_cache[root] = filetype_settings
  return filetype_settings
end

---@param bufnr integer
---@return ProjectFiletypeSettings|nil
local function get_buffer_filetype_settings(bufnr)
  local root = project_json.find_root(bufnr)
  if not root then
    return nil
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return nil
  end

  return merge_filetype_settings(load_filetype_settings(root), filetype)
end

---@param bufnr integer
function M.apply_filetype_settings(bufnr)
  if not buffer_utils.is_regular(bufnr) then
    return
  end

  local filetype_settings = get_buffer_filetype_settings(bufnr)
  if not filetype_settings then
    return
  end

  local filetype = vim.bo[bufnr].filetype

  if filetype_settings.detect_indentation == false and filetype ~= '' then
    vim.bo[bufnr].expandtab = vim.filetype.get_option(filetype, 'expandtab')
    vim.bo[bufnr].tabstop = vim.filetype.get_option(filetype, 'tabstop')
    vim.bo[bufnr].shiftwidth = vim.filetype.get_option(filetype, 'shiftwidth')
    vim.bo[bufnr].softtabstop = vim.filetype.get_option(filetype, 'softtabstop')
  end

  if filetype_settings.insert_spaces ~= nil then
    vim.bo[bufnr].expandtab = filetype_settings.insert_spaces
  end

  if filetype_settings.tab_size ~= nil then
    vim.bo[bufnr].tabstop = filetype_settings.tab_size
    vim.bo[bufnr].shiftwidth = filetype_settings.tab_size
    vim.bo[bufnr].softtabstop = filetype_settings.tab_size
  end
end

function M.invalidate()
  filetype_settings_cache = {}
end

---@param bufnr integer
---@return boolean|nil
function M.get_filetype_format_on_save(bufnr)
  local filetype_settings = get_buffer_filetype_settings(bufnr)
  if not filetype_settings then
    return nil
  end

  return filetype_settings.format_on_save
end

---@param group integer
function M.setup(group)
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    callback = function(args)
      -- These settings are buffer-local and depend on the detected filetype,
      -- so applying them on `FileType` is sufficient.
      M.apply_filetype_settings(args.buf)
    end,
  })
end

return M
