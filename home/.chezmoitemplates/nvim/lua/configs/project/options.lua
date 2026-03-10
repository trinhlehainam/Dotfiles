local buffer_utils = require('utils.buffer')
local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'

---@class ProjectEditorLanguageSettings
---@field insert_spaces? boolean
---@field tab_size? number
---@field detect_indentation? boolean
---@field format_on_save? boolean

---@type table<string, table<string, ProjectEditorLanguageSettings>>
local language_cache = {}

---@param key string
local function warn_ignored(key)
  log.warn(('Ignored unsupported key "%s" in %s'):format(key, VSCODE_SETTINGS), TITLE)
end

---@param filetype string
---@return string[]
local function filetype_keys(filetype)
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

---@param languages table<string, ProjectEditorLanguageSettings>
---@param filetype string
---@return ProjectEditorLanguageSettings
local function merge_language_settings(languages, filetype)
  local merged = {}

  for _, key in ipairs(filetype_keys(filetype)) do
    merged = vim.tbl_extend('force', merged, languages[key] or {})
  end

  return merged
end

---@param key string
---@param raw any
---@param languages table<string, ProjectEditorLanguageSettings>
local function parse_language_block(key, raw, languages)
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
    languages[filetype] = vim.tbl_extend('force', languages[filetype] or {}, settings)
  end
end

---@param root string
---@return table<string, ProjectEditorLanguageSettings>
local function load_languages(root)
  if language_cache[root] then
    return language_cache[root]
  end

  local raw = project_json.read_json(root, VSCODE_SETTINGS)
  local languages = {}

  for _, key in ipairs(common.sorted_keys(raw)) do
    if key:match('^%[.+%]$') then
      parse_language_block(key, raw[key], languages)
    end
  end

  language_cache[root] = languages
  return languages
end

---@param bufnr integer
---@return ProjectEditorLanguageSettings|nil
local function get_language_settings(bufnr)
  local root = project_json.find_root(bufnr)
  if not root then
    return nil
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return nil
  end

  return merge_language_settings(load_languages(root), filetype)
end

---@param bufnr integer
function M.apply(bufnr)
  if not buffer_utils.is_regular(bufnr) then
    return
  end

  local settings = get_language_settings(bufnr)
  if not settings then
    return
  end

  local filetype = vim.bo[bufnr].filetype

  if settings.detect_indentation == false and filetype ~= '' then
    vim.bo[bufnr].expandtab = vim.filetype.get_option(filetype, 'expandtab')
    vim.bo[bufnr].tabstop = vim.filetype.get_option(filetype, 'tabstop')
    vim.bo[bufnr].shiftwidth = vim.filetype.get_option(filetype, 'shiftwidth')
    vim.bo[bufnr].softtabstop = vim.filetype.get_option(filetype, 'softtabstop')
  end

  if settings.insert_spaces ~= nil then
    vim.bo[bufnr].expandtab = settings.insert_spaces
  end

  if settings.tab_size ~= nil then
    vim.bo[bufnr].tabstop = settings.tab_size
    vim.bo[bufnr].shiftwidth = settings.tab_size
    vim.bo[bufnr].softtabstop = settings.tab_size
  end
end

function M.invalidate()
  language_cache = {}
end

---@param bufnr integer
---@return boolean|nil
function M.get_format_on_save(bufnr)
  local settings = get_language_settings(bufnr)
  if not settings then
    return nil
  end

  return settings.format_on_save
end

---@param group integer
function M.setup(group)
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    callback = function(args)
      -- These settings are buffer-local and depend on the detected filetype,
      -- so applying them on `FileType` is sufficient.
      M.apply(args.buf)
    end,
  })
end

return M
