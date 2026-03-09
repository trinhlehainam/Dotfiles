local log = require('utils.log')
local project_json = require('configs.project_json')

local M = {}

local ROOT_MARKERS = { '.git', '.jj', '.nvim', '.vscode' }
local VSCODE_SETTINGS = '.vscode/settings.json'
local TOOLING_SETTINGS = '.nvim/tooling.json'
local TITLE = 'project-settings'

local editor_cache = {}
local tooling_cache = {}
local fileencodings_stack = {}
local setup_done = false

local conform_override_hooks = {}
local conform_base_overrides = {}
local lint_override_hooks = {}
local lint_base_overrides = {}

local encoding_aliases = {
  utf8 = 'utf-8',
  ['utf-8'] = 'utf-8',
  shiftjis = 'cp932',
  ['shift-jis'] = 'cp932',
  sjis = 'sjis',
  cp932 = 'cp932',
  windows31j = 'cp932',
  eucjp = 'euc-jp',
  ['euc-jp'] = 'euc-jp',
  windows1252 = 'latin1',
}

local function normalize_path(path)
  return (path or ''):gsub('\\', '/')
end

local function sorted_keys(tbl)
  local keys = vim.tbl_keys(tbl or {})
  table.sort(keys)
  return keys
end

local function warn_ignored(relpath, key)
  log.warn(('Ignored unsupported key "%s" in %s'):format(key, relpath), TITLE)
end

local function normalize_encoding(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  local normalized = value:lower():gsub('%s+', ''):gsub('_', '')
  return encoding_aliases[normalized] or value
end

local function normalize_encoding_list(values)
  local normalized = {}
  local seen = {}

  for _, value in ipairs(values or {}) do
    local encoding = normalize_encoding(value)
    if encoding and not seen[encoding] then
      seen[encoding] = true
      table.insert(normalized, encoding)
    end
  end

  return normalized
end

local function merge_unique(base, extra)
  local merged = vim.deepcopy(base or {})
  local seen = {}

  for _, name in ipairs(merged) do
    seen[name] = true
  end

  for _, name in ipairs(extra or {}) do
    if type(name) == 'string' and name ~= '' and not seen[name] then
      seen[name] = true
      table.insert(merged, name)
    end
  end

  return merged
end

local function get_root_for_path(path)
  if path == nil or path == '' then
    return nil
  end

  local ok, root = pcall(vim.fs.root, path, ROOT_MARKERS)
  if ok then
    return root
  end

  return nil
end

local function get_root(bufnr)
  return project_json.find_root(bufnr)
end

local function glob_to_lua_pattern(glob)
  local chars = { '^' }
  local idx = 1
  glob = normalize_path(glob)

  while idx <= #glob do
    local char = glob:sub(idx, idx)
    local next_two = glob:sub(idx, idx + 1)

    if next_two == '**' then
      table.insert(chars, '.*')
      idx = idx + 2
    elseif char == '*' then
      table.insert(chars, '[^/]*')
      idx = idx + 1
    elseif char == '?' then
      table.insert(chars, '.')
      idx = idx + 1
    else
      table.insert(chars, (char:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1')))
      idx = idx + 1
    end
  end

  table.insert(chars, '$')
  return table.concat(chars)
end

local function parse_associations(raw)
  local associations = {}

  if type(raw) ~= 'table' then
    warn_ignored(VSCODE_SETTINGS, 'files.associations')
    return associations
  end

  for _, pattern in ipairs(sorted_keys(raw)) do
    local filetype = raw[pattern]
    if type(filetype) == 'string' and filetype ~= '' then
      table.insert(associations, {
        filetype = filetype,
        has_slash = normalize_path(pattern):find('/') ~= nil,
        matcher = glob_to_lua_pattern(pattern),
        raw = pattern,
      })
    else
      warn_ignored(VSCODE_SETTINGS, ('files.associations.%s'):format(pattern))
    end
  end

  table.sort(associations, function(left, right)
    if #left.raw == #right.raw then
      return left.raw > right.raw
    end

    return #left.raw > #right.raw
  end)

  return associations
end

local function parse_language_block(key, raw, editor)
  if type(raw) ~= 'table' then
    warn_ignored(VSCODE_SETTINGS, key)
    return
  end

  local languages = {}
  for language in key:gmatch('%[([^%]]+)%]') do
    table.insert(languages, language)
  end

  if #languages == 0 then
    warn_ignored(VSCODE_SETTINGS, key)
    return
  end

  local settings = {}
  for _, nested_key in ipairs(sorted_keys(raw)) do
    local value = raw[nested_key]

    if nested_key == 'editor.insertSpaces' and type(value) == 'boolean' then
      settings.insert_spaces = value
    elseif nested_key == 'editor.tabSize' and type(value) == 'number' then
      settings.tab_size = value
    elseif nested_key == 'editor.detectIndentation' and type(value) == 'boolean' then
      settings.detect_indentation = value
    elseif nested_key == 'editor.formatOnSave' and type(value) == 'boolean' then
      settings.format_on_save = value
    elseif nested_key == 'files.autoGuessEncoding' and type(value) == 'boolean' then
      settings.auto_guess_encoding = value
    elseif nested_key == 'files.candidateGuessEncodings' and vim.islist(value) then
      settings.candidate_guess_encodings = normalize_encoding_list(value)
    elseif nested_key == 'files.encoding' then
      settings.encoding = normalize_encoding(value)
    else
      warn_ignored(VSCODE_SETTINGS, ('%s.%s'):format(key, nested_key))
    end
  end

  for _, language in ipairs(languages) do
    editor.languages[language] = vim.tbl_extend('force', editor.languages[language] or {}, settings)
  end
end

local function load_editor_settings(root)
  if editor_cache[root] then
    return editor_cache[root]
  end

  local raw = project_json.read_json(root, VSCODE_SETTINGS)
  local editor = {
    associations = {},
    languages = {},
  }

  for _, key in ipairs(sorted_keys(raw)) do
    if key == 'files.associations' then
      editor.associations = parse_associations(raw[key])
    elseif key:match('^%[.+%]$') then
      parse_language_block(key, raw[key], editor)
    end
  end

  editor_cache[root] = editor
  return editor
end

local function parse_boolean_setting(relpath, key, value, dest, field)
  if type(value) == 'boolean' then
    dest[field] = value
  else
    warn_ignored(relpath, key)
  end
end

local function parse_name_list(relpath, key, value)
  if not vim.islist(value) then
    warn_ignored(relpath, key)
    return {}
  end

  local names = {}
  for _, item in ipairs(value) do
    if type(item) == 'string' and item ~= '' then
      table.insert(names, item)
    else
      warn_ignored(relpath, key)
    end
  end

  return names
end

local function parse_tool_args(relpath, scope, raw)
  if type(raw) ~= 'table' then
    warn_ignored(relpath, scope)
    return {}
  end

  local parsed = {}
  for _, key in ipairs(sorted_keys(raw)) do
    local value = raw[key]

    if key == 'args' and vim.islist(value) then
      parsed.args = vim.deepcopy(value)
    elseif key == 'args_append' and vim.islist(value) then
      parsed.args_append = vim.deepcopy(value)
    else
      warn_ignored(relpath, ('%s.%s'):format(scope, key))
    end
  end

  return parsed
end

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

  for _, key in ipairs(sorted_keys(raw)) do
    local value = raw[key]

    if key == 'defaults' and type(value) == 'table' then
      for _, nested_key in ipairs(sorted_keys(value)) do
        if nested_key == 'format_on_save' then
          parse_boolean_setting(TOOLING_SETTINGS, 'defaults.format_on_save', value[nested_key], tooling.defaults, 'format_on_save')
        elseif nested_key == 'lint_on_save' then
          parse_boolean_setting(TOOLING_SETTINGS, 'defaults.lint_on_save', value[nested_key], tooling.defaults, 'lint_on_save')
        else
          warn_ignored(TOOLING_SETTINGS, ('defaults.%s'):format(nested_key))
        end
      end
    elseif key == 'filetypes' and type(value) == 'table' then
      for _, filetype in ipairs(sorted_keys(value)) do
        local filetype_value = value[filetype]
        if type(filetype_value) ~= 'table' then
          warn_ignored(TOOLING_SETTINGS, ('filetypes.%s'):format(filetype))
        else
          local parsed = {}
          for _, nested_key in ipairs(sorted_keys(filetype_value)) do
            local nested_value = filetype_value[nested_key]
            if nested_key == 'formatters' then
              parsed.formatters = parse_name_list(TOOLING_SETTINGS, ('filetypes.%s.formatters'):format(filetype), nested_value)
            elseif nested_key == 'linters' then
              parsed.linters = parse_name_list(TOOLING_SETTINGS, ('filetypes.%s.linters'):format(filetype), nested_value)
            elseif nested_key == 'format_on_save' then
              parse_boolean_setting(TOOLING_SETTINGS, ('filetypes.%s.format_on_save'):format(filetype), nested_value, parsed, 'format_on_save')
            elseif nested_key == 'lint_on_save' then
              parse_boolean_setting(TOOLING_SETTINGS, ('filetypes.%s.lint_on_save'):format(filetype), nested_value, parsed, 'lint_on_save')
            else
              warn_ignored(TOOLING_SETTINGS, ('filetypes.%s.%s'):format(filetype, nested_key))
            end
          end
          tooling.filetypes[filetype] = parsed
        end
      end
    elseif key == 'formatters' and type(value) == 'table' then
      for _, name in ipairs(sorted_keys(value)) do
        tooling.formatters[name] = parse_tool_args(TOOLING_SETTINGS, ('formatters.%s'):format(name), value[name])
      end
    elseif key == 'linters' and type(value) == 'table' then
      for _, name in ipairs(sorted_keys(value)) do
        tooling.linters[name] = parse_tool_args(TOOLING_SETTINGS, ('linters.%s'):format(name), value[name])
      end
    else
      warn_ignored(TOOLING_SETTINGS, key)
    end
  end

  tooling_cache[root] = tooling
  return tooling
end

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

local function get_language_settings(bufnr)
  local root = get_root(bufnr)
  if not root then
    return nil
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return nil
  end

  local editor = load_editor_settings(root)
  local merged = {}

  for _, key in ipairs(filetype_keys(filetype)) do
    merged = vim.tbl_extend('force', merged, editor.languages[key] or {})
  end

  return merged
end

local function get_tooling_settings(bufnr)
  local root = get_root(bufnr)
  if not root then
    return nil
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return nil
  end

  local tooling = load_tooling_settings(root)
  local merged = vim.deepcopy(tooling.defaults)
  merged.formatters = {}
  merged.linters = {}

  for _, key in ipairs(filetype_keys(filetype)) do
    local filetype_settings = tooling.filetypes[key]
    if filetype_settings then
      merged.formatters = merge_unique(merged.formatters, filetype_settings.formatters)
      merged.linters = merge_unique(merged.linters, filetype_settings.linters)
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

local function match_project_filetype(path, bufnr)
  local root = get_root(bufnr) or get_root_for_path(path)
  if not root then
    return nil
  end

  local editor = load_editor_settings(root)
  if #editor.associations == 0 then
    return nil
  end

  local normalized_path = normalize_path(path)
  local normalized_root = normalize_path(root)
  local relative_path = normalized_path
  if normalized_path:sub(1, #normalized_root + 1) == normalized_root .. '/' then
    relative_path = normalized_path:sub(#normalized_root + 2)
  end

  local basename = vim.fs.basename(normalized_path)
  for _, association in ipairs(editor.associations) do
    local candidate = association.has_slash and relative_path or basename
    if candidate:match(association.matcher) then
      return association.filetype
    end
  end

  return nil
end

local function apply_editor_settings(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= '' then
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

  if settings.encoding then
    vim.bo[bufnr].fileencoding = settings.encoding
  end
end

local function get_read_fileencodings(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return nil
  end

  local filetype = vim.filetype.match({ buf = bufnr, filename = name }) or ''
  if filetype == '' then
    return nil
  end

  local root = get_root(bufnr) or get_root_for_path(name)
  if not root then
    return nil
  end

  local editor = load_editor_settings(root)
  local settings = {}
  for _, key in ipairs(filetype_keys(filetype)) do
    settings = vim.tbl_extend('force', settings, editor.languages[key] or {})
  end

  local encodings = {}
  if settings.encoding then
    table.insert(encodings, settings.encoding)
  end

  if settings.auto_guess_encoding == false then
    return #encodings > 0 and table.concat(encodings, ',') or nil
  end

  encodings = merge_unique(encodings, settings.candidate_guess_encodings or {})
  if #encodings == 0 then
    return nil
  end

  return table.concat(encodings, ',')
end

local function restore_fileencodings(bufnr)
  local previous = fileencodings_stack[bufnr]
  if previous == nil then
    return
  end

  vim.o.fileencodings = previous
  fileencodings_stack[bufnr] = nil
end

local function register_filetype_dispatch()
  vim.filetype.add({
    pattern = {
      -- Keep one global dispatcher and resolve associations from the current root registry.
      ['.*'] = {
        function(path, bufnr)
          return match_project_filetype(path, bufnr)
        end,
        { priority = 1000 },
      },
    },
  })
end

local function redetect_filetype(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return
  end

  local detected, on_detect = vim.filetype.match({ buf = bufnr, filename = name })
  if detected and detected ~= vim.bo[bufnr].filetype then
    vim.bo[bufnr].filetype = detected
    if on_detect then
      on_detect(bufnr)
    end
  end
end

local function create_reload_command()
  local ok, err = pcall(vim.api.nvim_create_user_command, 'ProjectSettingsReload', function()
    project_json.invalidate()
    editor_cache = {}
    tooling_cache = {}

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == '' then
        redetect_filetype(bufnr)
        apply_editor_settings(bufnr)
      end
    end

    local message = 'Project settings reloaded'
    if #vim.lsp.get_clients() > 0 then
      message = message .. '; restart LSP clients to reload local server settings'
    end
    log.info(message, TITLE)
  end, { desc = 'Reload project-local JSON settings' })

  if not ok and not tostring(err):match('E174') then
    log.warn(('Failed to create :ProjectSettingsReload: %s'):format(tostring(err)), TITLE)
  end
end

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

function M.get_project_formatters(bufnr)
  M.ensure_conform_overrides(bufnr)

  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return {}
  end

  return vim.deepcopy(tooling.formatters or {})
end

function M.get_project_linters(bufnr)
  M.ensure_lint_overrides(bufnr)

  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return {}
  end

  return vim.deepcopy(tooling.linters or {})
end

function M.get_editor_format_on_save(bufnr)
  local settings = get_language_settings(bufnr)
  if not settings then
    return nil
  end

  return settings.format_on_save
end

function M.get_tooling_format_on_save(bufnr)
  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return nil
  end

  return tooling.format_on_save
end

function M.get_tooling_lint_on_save(bufnr)
  local tooling = get_tooling_settings(bufnr)
  if not tooling then
    return nil
  end

  return tooling.lint_on_save
end

function M.setup()
  if setup_done then
    return
  end

  register_filetype_dispatch()
  create_reload_command()

  local group = vim.api.nvim_create_augroup('project-settings', { clear = true })

  vim.api.nvim_create_autocmd('BufReadPre', {
    group = group,
    callback = function(args)
      local fileencodings = get_read_fileencodings(args.buf)
      if not fileencodings then
        return
      end

      -- `fileencodings` is global, so only override it while this buffer is being read.
      fileencodings_stack[args.buf] = vim.o.fileencodings
      vim.o.fileencodings = fileencodings
    end,
  })

  vim.api.nvim_create_autocmd('BufReadPost', {
    group = group,
    callback = function(args)
      restore_fileencodings(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
    group = group,
    callback = function(args)
      apply_editor_settings(args.buf)
    end,
  })

  setup_done = true
end

return M
