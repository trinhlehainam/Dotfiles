local buffer_utils = require('utils.buffer')
local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')
local vscode_settings = require('configs.project.vscode_settings')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'
local BUFFER_INDENT_MANAGED_KEY = 'project_settings_indent_managed'

---@type table<string, dotfiles.project.FiletypeSettingsMap>
local filetype_settings_cache = {}
local suspend_filetype_apply = false

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

---@param filetype_settings dotfiles.project.FiletypeSettings|nil
---@return boolean
local function is_indent_managed_by_settings(filetype_settings)
  return type(filetype_settings) == 'table'
    and (
      filetype_settings.detect_indentation == false
      or filetype_settings.insert_spaces ~= nil
      or filetype_settings.tab_size ~= nil
    )
end

---@param bufnr integer
---@return boolean
local function is_indent_managed(bufnr)
  return vim.b[bufnr][BUFFER_INDENT_MANAGED_KEY] == true
end

---@param bufnr integer
---@param managed boolean
local function set_indent_managed(bufnr, managed)
  vim.b[bufnr][BUFFER_INDENT_MANAGED_KEY] = managed or nil
end

---@param filetype_settings dotfiles.project.FiletypeSettingsMap
---@param filetype string
---@return dotfiles.project.FiletypeSettings
local function merge_filetype_settings(filetype_settings, filetype)
  local merged = {}

  for _, key in ipairs(expand_filetype_keys(filetype)) do
    merged = vim.tbl_extend('force', merged, filetype_settings[key] or {})
  end

  return merged
end

---@param filetype string
---@param raw any
---@param filetype_settings dotfiles.project.FiletypeSettingsMap
local function parse_filetype_settings_block(filetype, raw, filetype_settings)
  if type(raw) ~= 'table' then
    return
  end

  local editor_settings = type(raw.editor) == 'table' and raw.editor or raw
  local has_editor_keys = type(raw.editor) == 'table'
  if not has_editor_keys then
    for key in pairs(editor_settings) do
      if
        key == 'editor.insertSpaces'
        or key == 'editor.tabSize'
        or key == 'editor.detectIndentation'
        or key == 'editor.formatOnSave'
      then
        has_editor_keys = true
        break
      end
    end
  end

  if not has_editor_keys then
    return
  end

  local settings = {}
  for _, nested_key in ipairs(common.sorted_keys(editor_settings)) do
    local value = editor_settings[nested_key]

    if
      (nested_key == 'insertSpaces' or nested_key == 'editor.insertSpaces')
      and type(value) == 'boolean'
    then
      settings.insert_spaces = value
    elseif nested_key == 'tabSize' or nested_key == 'editor.tabSize' then
      -- Neovim's tabstop accepts integers from 1 through 9999.
      if type(value) == 'number' and value >= 1 and value <= 9999 and value % 1 == 0 then
        settings.tab_size = value
      else
        warn_ignored(('%s.editor.tabSize'):format(filetype))
      end
    elseif
      (nested_key == 'detectIndentation' or nested_key == 'editor.detectIndentation')
      and type(value) == 'boolean'
    then
      settings.detect_indentation = value
    elseif
      (nested_key == 'formatOnSave' or nested_key == 'editor.formatOnSave')
      and type(value) == 'boolean'
    then
      settings.format_on_save = value
    elseif type(raw.editor) == 'table' then
      warn_ignored(('%s.editor.%s'):format(filetype, nested_key))
    end
  end

  if next(settings) ~= nil then
    filetype_settings[filetype] =
      vim.tbl_extend('force', filetype_settings[filetype] or {}, settings)
  end
end

---@param root string
---@return dotfiles.project.FiletypeSettingsMap
local function load_filetype_settings(root)
  if filetype_settings_cache[root] then
    return filetype_settings_cache[root]
  end

  local raw = vscode_settings.read(root)
  local filetype_settings = {}

  for _, key in ipairs(common.sorted_keys(raw)) do
    if type(raw[key]) == 'table' then
      parse_filetype_settings_block(key, raw[key], filetype_settings)
    end
  end

  filetype_settings_cache[root] = filetype_settings
  return filetype_settings
end

---@param root string
---@param filetype string
---@return dotfiles.project.FiletypeSettings|nil
local function get_root_filetype_settings(root, filetype)
  if type(root) ~= 'string' or root == '' or type(filetype) ~= 'string' or filetype == '' then
    return nil
  end

  local merged = merge_filetype_settings(load_filetype_settings(root), filetype)
  if next(merged) == nil then
    return nil
  end

  return merged
end

---@param bufnr integer
---@param root string|nil
---@return dotfiles.project.FiletypeSettings|nil
---@return string
local function resolve_buffer_filetype_settings(bufnr, root)
  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return nil, filetype
  end

  if type(root) ~= 'string' or root == '' then
    return nil, filetype
  end

  return get_root_filetype_settings(root, filetype), filetype
end

---@param bufnr integer
---@param filetype string
local function reset_indent_options(bufnr, filetype)
  if filetype == '' then
    vim.bo[bufnr].expandtab = vim.go.expandtab
    vim.bo[bufnr].tabstop = vim.go.tabstop
    vim.bo[bufnr].shiftwidth = vim.go.shiftwidth
    vim.bo[bufnr].softtabstop = vim.go.softtabstop
    return
  end

  -- `vim.filetype.get_option()` caches the result after triggering `FileType`
  -- once, so suppress this module's project-local callback during the lookup to
  -- avoid polluting the global cache with root-specific values.
  suspend_filetype_apply = true
  local ok, err = xpcall(function()
    vim.bo[bufnr].expandtab = vim.filetype.get_option(filetype, 'expandtab')
    vim.bo[bufnr].tabstop = vim.filetype.get_option(filetype, 'tabstop')
    vim.bo[bufnr].shiftwidth = vim.filetype.get_option(filetype, 'shiftwidth')
    vim.bo[bufnr].softtabstop = vim.filetype.get_option(filetype, 'softtabstop')
  end, debug.traceback)
  suspend_filetype_apply = false

  if not ok then
    error(err)
  end
end

---@param bufnr integer
---@param filetype_settings dotfiles.project.FiletypeSettings
local function apply_resolved_filetype_settings(bufnr, filetype_settings)
  if filetype_settings.insert_spaces ~= nil then
    vim.bo[bufnr].expandtab = filetype_settings.insert_spaces
  end

  if filetype_settings.tab_size ~= nil then
    vim.bo[bufnr].tabstop = filetype_settings.tab_size
    vim.bo[bufnr].shiftwidth = filetype_settings.tab_size
    vim.bo[bufnr].softtabstop = filetype_settings.tab_size
  end
end

---@param bufnr integer
---@param filetype string
---@param filetype_settings dotfiles.project.FiletypeSettings|nil
local function sync_buffer_filetype_settings(bufnr, filetype, filetype_settings)
  local managed = is_indent_managed_by_settings(filetype_settings)
  if managed or is_indent_managed(bufnr) then
    reset_indent_options(bufnr, filetype)
  end

  if filetype_settings then
    apply_resolved_filetype_settings(bufnr, filetype_settings)
  end

  set_indent_managed(bufnr, managed)
end

---@param bufnr integer
---@param root string|nil
local function sync_buffer_settings_for_root(bufnr, root)
  local filetype_settings, filetype = resolve_buffer_filetype_settings(bufnr, root)
  if not filetype_settings and not is_indent_managed(bufnr) then
    return
  end

  sync_buffer_filetype_settings(bufnr, filetype, filetype_settings)
end

---@param bufnr integer
local function schedule_filetype_apply(bufnr)
  -- Run after the current autocmd stack so project-local settings win even if
  -- another `BufReadPost`/`BufWritePost` handler updates indentation later.
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.apply_filetype_settings(bufnr)
    end
  end)
end

---@param bufnr integer
function M.apply_filetype_settings(bufnr)
  if not buffer_utils.is_regular(bufnr) then
    return
  end

  sync_buffer_settings_for_root(bufnr, project_json.find_root(bufnr))
end

---@param bufnr integer
---@param root string
function M.apply_filetype_settings_for_root(bufnr, root)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  sync_buffer_settings_for_root(bufnr, root)
end

function M.invalidate()
  filetype_settings_cache = {}
end

---@param bufnr integer
---@return boolean|nil
function M.get_filetype_format_on_save(bufnr)
  local filetype_settings = resolve_buffer_filetype_settings(bufnr, project_json.find_root(bufnr))
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
      if not suspend_filetype_apply then
        M.apply_filetype_settings(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
    group = group,
    callback = function(args)
      schedule_filetype_apply(args.buf)
    end,
  })
end

return M
