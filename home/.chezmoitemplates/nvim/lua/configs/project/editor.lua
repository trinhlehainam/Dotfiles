local buffer_utils = require('utils.buffer')
local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'

---@class ProjectPatternAssociation
---@field filetype string
---@field has_slash boolean
---@field path_pattern string
---@field raw string

---@class ProjectEditorAssociations
---@field extensions table<string, string>
---@field filenames table<string, string>
---@field patterns ProjectPatternAssociation[]

---@class ProjectEditorLanguageSettings
---@field insert_spaces? boolean
---@field tab_size? number
---@field detect_indentation? boolean
---@field format_on_save? boolean
---@field auto_guess_encoding? boolean
---@field candidate_guess_encodings? string[]
---@field encoding? string

---@class ProjectEditorSettings
---@field associations ProjectEditorAssociations
---@field languages table<string, ProjectEditorLanguageSettings>

---@type table<string, ProjectEditorSettings>
local editor_cache = {}
---@type table<string, table<string, boolean>>
local filetype_patterns_by_root = {}
---@type table<string, boolean>
local filetype_extensions = {}
---@type table<string, boolean>
local filetype_filenames = {}
---@type table<integer, string>
local fileencodings_stack = {}

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

---@param path string|nil
---@return string
local function normalize_path(path)
  return (path or ''):gsub('\\', '/')
end

---@param key string
local function warn_ignored(key)
  log.warn(('Ignored unsupported key "%s" in %s'):format(key, VSCODE_SETTINGS), TITLE)
end

---@param value any
---@return string|nil
local function normalize_encoding(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  local normalized = value:lower():gsub('%s+', ''):gsub('_', '')
  return encoding_aliases[normalized] or value
end

---@param values string[]|nil
---@return string[]
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

---@param text string
---@return string
local function escape_lua_pattern(text)
  return (normalize_path(text):gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'))
end

---@param glob string
---@return string|nil
local function simple_extension_key(glob)
  glob = normalize_path(glob)
  if glob:find('/') ~= nil or not glob:match('^%*%.') then
    return nil
  end

  local extension = glob:sub(3)
  if extension == '' or extension:find('%.') ~= nil or extension:find('[%*%?]') ~= nil then
    return nil
  end

  return extension
end

---@param glob string
---@return string|nil
local function simple_filename_key(glob)
  glob = normalize_path(glob)
  if glob == '' or glob:find('/') ~= nil or glob:find('[%*%?]') ~= nil then
    return nil
  end

  return glob
end

---@return ProjectEditorAssociations
local function empty_associations()
  return {
    extensions = {},
    filenames = {},
    patterns = {},
  }
end

---@param glob string
---@param anchored? boolean
---@return string
local function glob_to_lua_pattern(glob, anchored)
  local chars = anchored == false and {} or { '^' }
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
      table.insert(chars, escape_lua_pattern(char))
      idx = idx + 1
    end
  end

  if anchored ~= false then
    table.insert(chars, '$')
  end

  return table.concat(chars)
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

---@param raw table
---@return ProjectEditorAssociations
local function parse_associations(raw)
  local associations = empty_associations()

  if type(raw) ~= 'table' then
    warn_ignored('files.associations')
    return associations
  end

  -- Only lower exact `*.ext` and exact basename entries into Neovim's
  -- extension/filename tables. Anything path-sensitive or glob-like stays on
  -- the pattern path so the root-aware matcher keeps the original behavior.
  for _, pattern in ipairs(common.sorted_keys(raw)) do
    local filetype = raw[pattern]
    if type(filetype) == 'string' and filetype ~= '' then
      local normalized = normalize_path(pattern)
      local extension = simple_extension_key(normalized)
      local filename = extension == nil and simple_filename_key(normalized) or nil

      if extension then
        associations.extensions[extension] = filetype
      elseif filename then
        associations.filenames[filename] = filetype
      else
        table.insert(associations.patterns, {
          filetype = filetype,
          has_slash = normalized:find('/') ~= nil,
          path_pattern = glob_to_lua_pattern(normalized, false),
          raw = normalized,
        })
      end
    else
      warn_ignored(('files.associations.%s'):format(pattern))
    end
  end

  table.sort(associations.patterns, function(left, right)
    if #left.raw == #right.raw then
      return left.raw > right.raw
    end

    return #left.raw > #right.raw
  end)

  return associations
end

---@param key string
---@param raw table
---@param editor ProjectEditorSettings
local function parse_language_block(key, raw, editor)
  if type(raw) ~= 'table' then
    warn_ignored(key)
    return
  end

  local languages = {}
  for language in key:gmatch('%[([^%]]+)%]') do
    table.insert(languages, language)
  end

  if #languages == 0 then
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
    elseif nested_key == 'files.autoGuessEncoding' and type(value) == 'boolean' then
      settings.auto_guess_encoding = value
    elseif nested_key == 'files.candidateGuessEncodings' and vim.islist(value) then
      settings.candidate_guess_encodings = normalize_encoding_list(value)
    elseif nested_key == 'files.encoding' then
      settings.encoding = normalize_encoding(value)
    else
      warn_ignored(('%s.%s'):format(key, nested_key))
    end
  end

  for _, language in ipairs(languages) do
    editor.languages[language] = vim.tbl_extend('force', editor.languages[language] or {}, settings)
  end
end

---@param root string
---@return ProjectEditorSettings
local function load_editor_settings(root)
  if editor_cache[root] then
    return editor_cache[root]
  end

  local raw = project_json.read_json(root, VSCODE_SETTINGS)
  local editor = {
    associations = empty_associations(),
    languages = {},
  }

  for _, key in ipairs(common.sorted_keys(raw)) do
    if key == 'files.associations' then
      editor.associations = parse_associations(raw[key])
    elseif key:match('^%[.+%]$') then
      parse_language_block(key, raw[key], editor)
    end
  end

  editor_cache[root] = editor
  return editor
end

---@param path string
---@param resolver fun(associations: ProjectEditorAssociations): string|nil
---@return string|nil
local function resolve_filetype_for_path(path, resolver)
  local root = project_json.find_root_for_path(path)
  if not root then
    return nil
  end

  return resolver(load_editor_settings(root).associations)
end

---@param extensions table<string, string>
local function register_filetype_extensions(extensions)
  local mapping = {}

  for extension in pairs(extensions) do
    if not filetype_extensions[extension] then
      filetype_extensions[extension] = true
      mapping[extension] = function(path)
        return resolve_filetype_for_path(path, function(associations)
          return associations.extensions[extension]
        end)
      end
    end
  end

  if next(mapping) ~= nil then
    -- Simple `*.ext` rules can use Neovim's extension dispatch as long as the
    -- function re-checks the current project root before returning a filetype.
    vim.filetype.add({ extension = mapping })
  end
end

---@param filenames table<string, string>
local function register_filetype_filenames(filenames)
  local mapping = {}

  for filename in pairs(filenames) do
    if not filetype_filenames[filename] then
      filetype_filenames[filename] = true
      mapping[filename] = function(path)
        return resolve_filetype_for_path(path, function(associations)
          return associations.filenames[filename]
        end)
      end
    end
  end

  if next(mapping) ~= nil then
    vim.filetype.add({ filename = mapping })
  end
end

---@param root string
---@return table<string, { [1]: string, [2]: { priority: integer } }>
local function build_filetype_patterns(root)
  local editor = load_editor_settings(root)
  local patterns = {}
  local root_pattern = escape_lua_pattern(root)

  for _, association in ipairs(editor.associations.patterns) do
    local value = { association.filetype, { priority = 1000 + #association.raw } }
    local path_pattern = root_pattern .. '/' .. association.path_pattern

    patterns[path_pattern] = value

    if not association.has_slash then
      patterns[root_pattern .. '/.*/' .. association.path_pattern] = value
    end
  end

  return patterns
end

---@param root string
local function register_filetype_patterns(root)
  if type(root) ~= 'string' or root == '' then
    return
  end

  local current = build_filetype_patterns(root)
  local previous = filetype_patterns_by_root[root] or {}
  local patterns = vim.deepcopy(current)

  for pattern in pairs(previous) do
    if current[pattern] == nil then
      -- `vim.filetype.add()` only overwrites existing entries; registering a
      -- nil matcher lets reloads remove stale patterns from the active registry.
      patterns[pattern] = function()
        return nil
      end
    end
  end

  if next(patterns) ~= nil then
    vim.filetype.add({ pattern = patterns })
  end

  local active = {}
  for pattern in pairs(current) do
    active[pattern] = true
  end
  filetype_patterns_by_root[root] = active
end

---@param path string
local function ensure_filetype_mappings_for_path(path)
  if type(path) ~= 'string' or path == '' then
    return
  end

  local root = project_json.find_root_for_path(path)
  if root then
    local associations = load_editor_settings(root).associations
    register_filetype_extensions(associations.extensions)
    register_filetype_filenames(associations.filenames)
    register_filetype_patterns(root)
  end
end

---@param bufnr integer
---@return string|nil
local function get_root(bufnr)
  return project_json.find_root(bufnr)
end

---@param bufnr integer
---@return ProjectEditorLanguageSettings|nil
local function get_language_settings(bufnr)
  local root = get_root(bufnr)
  if not root then
    return nil
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return nil
  end

  return merge_language_settings(load_editor_settings(root).languages, filetype)
end

---@param bufnr integer
local function apply_editor_settings(bufnr)
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

  if settings.encoding then
    vim.bo[bufnr].fileencoding = settings.encoding
  end
end

---@param bufnr integer
---@return string|nil
local function get_read_fileencodings(bufnr)
  local name = buffer_utils.name(bufnr)
  if name == '' then
    return nil
  end

  local filetype = vim.filetype.match({ buf = bufnr, filename = name }) or ''
  if filetype == '' then
    return nil
  end

  local root = get_root(bufnr) or project_json.find_root_for_path(name)
  if not root then
    return nil
  end

  local settings = merge_language_settings(load_editor_settings(root).languages, filetype)

  local encodings = {}
  if settings.encoding then
    table.insert(encodings, settings.encoding)
  end

  if settings.auto_guess_encoding == false then
    return #encodings > 0 and table.concat(encodings, ',') or nil
  end

  encodings = common.merge_unique_strings(encodings, settings.candidate_guess_encodings or {})
  if #encodings == 0 then
    return nil
  end

  return table.concat(encodings, ',')
end

---@param bufnr integer
local function restore_fileencodings(bufnr)
  local previous = fileencodings_stack[bufnr]
  if previous == nil then
    return
  end

  vim.o.fileencodings = previous
  fileencodings_stack[bufnr] = nil
end

---@param bufnr integer
local function redetect_filetype(bufnr)
  local name = buffer_utils.name(bufnr)
  if name == '' then
    return
  end

  ensure_filetype_mappings_for_path(name)
  local detected, on_detect = vim.filetype.match({ buf = bufnr, filename = name })
  if detected and detected ~= vim.bo[bufnr].filetype then
    vim.bo[bufnr].filetype = detected
    if on_detect then
      on_detect(bufnr)
    end
  end
end

local function register_startup_filetype_mappings()
  -- Startup filetype detection runs before later buffer events, so seed the
  -- current cwd and command-line file arguments here.
  ensure_filetype_mappings_for_path(vim.uv.cwd() or vim.fn.getcwd())

  for _, arg in ipairs(vim.fn.argv()) do
    if type(arg) == 'string' and arg ~= '' and arg ~= '-' then
      ensure_filetype_mappings_for_path(vim.fn.fnamemodify(arg, ':p'))
    end
  end
end

function M.invalidate()
  editor_cache = {}
end

function M.refresh_open_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if buffer_utils.is_regular(bufnr) then
      redetect_filetype(bufnr)
      apply_editor_settings(bufnr)
    end
  end
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
  vim.api.nvim_create_autocmd('BufReadPre', {
    group = group,
    callback = function(args)
      ensure_filetype_mappings_for_path(args.file)

      local fileencodings = get_read_fileencodings(args.buf)
      if not fileencodings then
        return
      end

      -- `fileencodings` is global, so only override it while this one buffer
      -- is being read, then restore it on `BufReadPost`.
      fileencodings_stack[args.buf] = vim.o.fileencodings
      vim.o.fileencodings = fileencodings
    end,
  })

  vim.api.nvim_create_autocmd('BufNewFile', {
    group = group,
    callback = function(args)
      ensure_filetype_mappings_for_path(args.file)
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

  register_startup_filetype_mappings()
end

return M
