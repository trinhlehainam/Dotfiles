local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')

local M = {}

local TITLE = 'project-settings'
local TOOLING_SETTINGS = '.nvim/tooling.json'

---@class dotfiles.ProjectToolArgs
---@field args? string[]
---@field args_append? string[]

---@class dotfiles.ProjectToolingDefaults
---@field format_on_save? boolean
---@field lint_on_save? boolean

---@class dotfiles.ProjectToolingFiletypeSettings
---@field formatters? string[]
---@field linters? string[]
---@field format_on_save? boolean
---@field lint_on_save? boolean

---@class dotfiles.ProjectToolingSettings
---@field defaults dotfiles.ProjectToolingDefaults
---@field filetypes table<string, dotfiles.ProjectToolingFiletypeSettings>
---@field formatters table<string, dotfiles.ProjectToolArgs>
---@field linters table<string, dotfiles.ProjectToolArgs>

---@class dotfiles.ProjectResolvedToolingSettings
---@field formatters string[]
---@field linters string[]
---@field format_on_save? boolean
---@field lint_on_save? boolean
---@field formatter_overrides table<string, dotfiles.ProjectToolArgs>
---@field linter_overrides table<string, dotfiles.ProjectToolArgs>

---@type table<string, dotfiles.ProjectToolingSettings>
local tooling_cache = {}
local conform_override_hooks = {}
local conform_base_overrides = {}
local lint_override_hooks = {}
local lint_base_overrides = {}

---@param key string
local function warn_ignored(key)
  log.warn(('Ignored unsupported key "%s" in %s'):format(key, TOOLING_SETTINGS), TITLE)
end

---@param relpath string
---@param key string
---@param value any
---@param dest table
---@param field string
local function parse_boolean_setting(relpath, key, value, dest, field)
  if type(value) == 'boolean' then
    dest[field] = value
  else
    log.warn(('Ignored unsupported key "%s" in %s'):format(key, relpath), TITLE)
  end
end

---@param relpath string
---@param key string
---@param value any
---@return string[]|nil
local function parse_string_list(relpath, key, value)
  if not vim.islist(value) then
    log.warn(('Ignored unsupported key "%s" in %s'):format(key, relpath), TITLE)
    return nil
  end

  local items = {}
  for _, item in ipairs(value) do
    if type(item) == 'string' and item ~= '' then
      table.insert(items, item)
    else
      log.warn(('Ignored unsupported key "%s" in %s'):format(key, relpath), TITLE)
    end
  end

  return items
end

---@param relpath string
---@param key string
---@param value any
---@return string[]
local function parse_name_list(relpath, key, value)
  return parse_string_list(relpath, key, value) or {}
end

---@param relpath string
---@param scope string
---@param raw table
---@return dotfiles.ProjectToolArgs
local function parse_tool_args(relpath, scope, raw)
  if type(raw) ~= 'table' then
    log.warn(('Ignored unsupported key "%s" in %s'):format(scope, relpath), TITLE)
    return {}
  end

  local parsed = {}
  for _, key in ipairs(common.sorted_keys(raw)) do
    local value = raw[key]

    if key == 'args' then
      local args = parse_string_list(relpath, ('%s.args'):format(scope), value)
      if args then
        parsed.args = args
      end
    elseif key == 'args_append' then
      local args_append = parse_string_list(relpath, ('%s.args_append'):format(scope), value)
      if args_append then
        parsed.args_append = args_append
      end
    else
      log.warn(
        ('Ignored unsupported key "%s" in %s'):format(('%s.%s'):format(scope, key), relpath),
        TITLE
      )
    end
  end

  return parsed
end

---@param raw table
---@param defaults dotfiles.ProjectToolingDefaults
local function parse_tooling_defaults(raw, defaults)
  if type(raw) ~= 'table' then
    warn_ignored('defaults')
    return
  end

  for _, key in ipairs(common.sorted_keys(raw)) do
    if key == 'format_on_save' then
      parse_boolean_setting(
        TOOLING_SETTINGS,
        'defaults.format_on_save',
        raw[key],
        defaults,
        'format_on_save'
      )
    elseif key == 'lint_on_save' then
      parse_boolean_setting(
        TOOLING_SETTINGS,
        'defaults.lint_on_save',
        raw[key],
        defaults,
        'lint_on_save'
      )
    else
      warn_ignored(('defaults.%s'):format(key))
    end
  end
end

---@param filetype string
---@param raw table
---@return dotfiles.ProjectToolingFiletypeSettings|nil
local function parse_tooling_filetype(filetype, raw)
  if type(raw) ~= 'table' then
    warn_ignored(('filetypes.%s'):format(filetype))
    return nil
  end

  local parsed = {}

  for _, key in ipairs(common.sorted_keys(raw)) do
    local value = raw[key]

    if key == 'formatters' then
      parsed.formatters =
        parse_name_list(TOOLING_SETTINGS, ('filetypes.%s.formatters'):format(filetype), value)
    elseif key == 'linters' then
      parsed.linters =
        parse_name_list(TOOLING_SETTINGS, ('filetypes.%s.linters'):format(filetype), value)
    elseif key == 'format_on_save' then
      parse_boolean_setting(
        TOOLING_SETTINGS,
        ('filetypes.%s.format_on_save'):format(filetype),
        value,
        parsed,
        'format_on_save'
      )
    elseif key == 'lint_on_save' then
      parse_boolean_setting(
        TOOLING_SETTINGS,
        ('filetypes.%s.lint_on_save'):format(filetype),
        value,
        parsed,
        'lint_on_save'
      )
    else
      warn_ignored(('filetypes.%s.%s'):format(filetype, key))
    end
  end

  return parsed
end

---@param root string
---@return dotfiles.ProjectToolingSettings
local function load_tooling_settings(root)
  if tooling_cache[root] then
    return tooling_cache[root]
  end

  local raw = project_json.read_json(root, TOOLING_SETTINGS)
  local tooling = {
    defaults = {},
    filetypes = {},
    formatters = {},
    linters = {},
  }

  for _, key in ipairs(common.sorted_keys(raw)) do
    local value = raw[key]

    if key == 'defaults' then
      parse_tooling_defaults(value, tooling.defaults)
    elseif key == 'filetypes' and type(value) == 'table' then
      for _, filetype in ipairs(common.sorted_keys(value)) do
        local parsed = parse_tooling_filetype(filetype, value[filetype])
        if parsed then
          tooling.filetypes[filetype] = parsed
        end
      end
    elseif key == 'formatters' and type(value) == 'table' then
      for _, name in ipairs(common.sorted_keys(value)) do
        tooling.formatters[name] =
          parse_tool_args(TOOLING_SETTINGS, ('formatters.%s'):format(name), value[name])
      end
    elseif key == 'linters' and type(value) == 'table' then
      for _, name in ipairs(common.sorted_keys(value)) do
        tooling.linters[name] =
          parse_tool_args(TOOLING_SETTINGS, ('linters.%s'):format(name), value[name])
      end
    else
      warn_ignored(key)
    end
  end

  tooling_cache[root] = tooling
  return tooling
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

---@param bufnr integer
---@return string|nil root
---@return string|nil filetype
local function get_buffer_context(bufnr)
  local root = project_json.find_root(bufnr)
  if not root then
    return nil
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return nil
  end

  return root, filetype
end

---@param bufnr integer
---@return dotfiles.ProjectResolvedToolingSettings|nil
local function get_tooling_settings(bufnr)
  local root, filetype = get_buffer_context(bufnr)
  if not root then
    return nil
  end

  local tooling = load_tooling_settings(root)
  local merged = vim.deepcopy(tooling.defaults)
  merged.formatters = {}
  merged.linters = {}

  for _, key in ipairs(filetype_keys(filetype)) do
    local filetype_settings = tooling.filetypes[key]
    if filetype_settings then
      merged.formatters =
        common.merge_unique_strings(merged.formatters, filetype_settings.formatters)
      merged.linters = common.merge_unique_strings(merged.linters, filetype_settings.linters)
      if filetype_settings.format_on_save ~= nil then
        merged.format_on_save = filetype_settings.format_on_save
      end
      if filetype_settings.lint_on_save ~= nil then
        merged.lint_on_save = filetype_settings.lint_on_save
      end
    end
  end

  merged.formatter_overrides = tooling.formatters
  merged.linter_overrides = tooling.linters
  return merged
end

---@param name string
---@return fun(bufnr: integer): table|nil
local function build_conform_override(name)
  return function(bufnr)
    local base = conform_base_overrides[name]
    if type(base) == 'function' then
      base = base(bufnr)
    end

    local tooling = get_tooling_settings(bufnr)
    local override = tooling and tooling.formatter_overrides[name] or nil
    if not override or (override.args == nil and override.args_append == nil) then
      return base
    end

    local project_override = { inherit = true }
    if override.args then
      project_override.args = vim.deepcopy(override.args)
    end
    if override.args_append then
      project_override.append_args = vim.deepcopy(override.args_append)
    end

    if base then
      return vim.tbl_deep_extend('force', vim.deepcopy(base), project_override)
    end

    return project_override
  end
end

---@param name string
---@return fun(): table|nil
local function build_lint_override(name)
  return function()
    local base = lint_base_overrides[name]
    if type(base) == 'function' then
      base = base()
    end

    if not base then
      return nil
    end

    local linter = vim.deepcopy(base)
    local tooling = get_tooling_settings(vim.api.nvim_get_current_buf())
    local override = tooling and tooling.linter_overrides[name] or nil
    if not override then
      return linter
    end

    if override.args then
      linter.args = vim.deepcopy(override.args)
    end
    if override.args_append then
      local args = vim.deepcopy(linter.args or {})
      vim.list_extend(args, vim.deepcopy(override.args_append))
      linter.args = args
    end

    return linter
  end
end

---@param hooks table<string, boolean>
---@param bases table<string, any>
---@param target table<string, any>|nil
local function restore_override_bases(hooks, bases, target)
  if not target then
    return
  end

  for name in pairs(hooks) do
    target[name] = bases[name]
  end
end

function M.invalidate()
  tooling_cache = {}

  local ok_conform, conform = pcall(require, 'conform')
  if ok_conform and type(conform.formatters) == 'table' then
    restore_override_bases(conform_override_hooks, conform_base_overrides, conform.formatters)
  end

  local ok_lint, lint = pcall(require, 'lint')
  if ok_lint and type(lint.linters) == 'table' then
    restore_override_bases(lint_override_hooks, lint_base_overrides, lint.linters)
  end

  conform_override_hooks = {}
  conform_base_overrides = {}
  lint_override_hooks = {}
  lint_base_overrides = {}
end

---@param bufnr integer
function M.ensure_conform_overrides(bufnr)
  local ok, conform = pcall(require, 'conform')
  if not ok then
    return
  end

  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return
  end

  for name in pairs(tooling.formatter_overrides or {}) do
    if not conform_override_hooks[name] then
      conform_base_overrides[name] = conform.formatters[name]
      conform.formatters[name] = build_conform_override(name)
      conform_override_hooks[name] = true
    end
  end
end

---@param bufnr integer
function M.ensure_lint_overrides(bufnr)
  local ok, lint = pcall(require, 'lint')
  if not ok then
    return
  end

  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return
  end

  for name in pairs(tooling.linter_overrides or {}) do
    if not lint_override_hooks[name] then
      local base = lint.linters[name]
      if base then
        lint_base_overrides[name] = base
        lint.linters[name] = build_lint_override(name)
        lint_override_hooks[name] = true
      else
        log.warn(('Ignored linter override for unknown linter "%s"'):format(name), TITLE)
      end
    end
  end
end

---@param bufnr integer
---@return string[]
function M.get_formatters(bufnr)
  M.ensure_conform_overrides(bufnr)

  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return {}
  end

  return vim.deepcopy(tooling.formatters or {})
end

---@param bufnr integer
---@return string[]
function M.get_linters(bufnr)
  M.ensure_lint_overrides(bufnr)

  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return {}
  end

  return vim.deepcopy(tooling.linters or {})
end

---@param bufnr integer
---@return boolean|nil
function M.get_format_on_save(bufnr)
  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return nil
  end

  return tooling.format_on_save
end

---@param bufnr integer
---@return boolean|nil
function M.get_lint_on_save(bufnr)
  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return nil
  end

  return tooling.lint_on_save
end

return M
