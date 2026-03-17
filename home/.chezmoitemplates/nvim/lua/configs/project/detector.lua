require('configs.project.types')

local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')
local vscode_settings = require('configs.project.vscode_settings')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'
local BUFFER_FILETYPE_MANAGED_KEY = 'project_settings_filetype_managed'

---@type table<string, ProjectFilesAssociations>
local files_associations_cache = {}
---@type table<string, table<string, boolean>>
local filetype_patterns_by_root = {}
---@type table<string, boolean>
local filetype_extensions = {}
---@type table<string, boolean>
local filetype_filenames = {}

---@param bufnr integer
---@return boolean
local function is_filetype_managed(bufnr)
  return vim.b[bufnr][BUFFER_FILETYPE_MANAGED_KEY] == true
end

---@param bufnr integer
---@param managed boolean
local function set_filetype_managed(bufnr, managed)
  vim.b[bufnr][BUFFER_FILETYPE_MANAGED_KEY] = managed or nil
end

---@param path string|nil
---@return string
local function normalize_path(path)
  return (path or ''):gsub('\\', '/')
end

---@param key string
local function warn_ignored(key)
  log.warn(('Ignored unsupported key "%s" in %s'):format(key, VSCODE_SETTINGS), TITLE)
end

---@param text string
---@return string
local function escape_lua_pattern(text)
  return (normalize_path(text):gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'))
end

---@param glob string
---@return string|nil
local function extract_simple_extension_from_glob(glob)
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
local function extract_simple_filename_from_glob(glob)
  glob = normalize_path(glob)
  if glob == '' or glob:find('/') ~= nil or glob:find('[%*%?]') ~= nil then
    return nil
  end

  return glob
end

---@return ProjectFilesAssociations
local function empty_files_associations()
  return {
    extensions = {},
    filenames = {},
    patterns = {},
  }
end

---Expand a single top-level `{a,b,c}` brace group in a glob string.
---@param glob string
---@return string[]
local function expand_braces(glob)
  local prefix, alternatives, suffix = glob:match('^(.-)%{([^}]+)%}(.*)$')
  if not prefix then
    return { glob }
  end

  local expanded = {}
  for alt in alternatives:gmatch('[^,]+') do
    table.insert(expanded, prefix .. alt .. suffix)
  end

  if #expanded == 0 then
    return { glob }
  end

  return expanded
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

---@param raw any
---@return ProjectFilesAssociations
local function parse_files_associations(raw)
  local files_associations = empty_files_associations()

  if raw == nil then
    return files_associations
  end

  if type(raw) ~= 'table' then
    warn_ignored('files.associations')
    return files_associations
  end

  -- Lower exact `*.ext` and exact basename entries into Neovim's fast
  -- extension/filename tables. Path-aware and glob-style rules stay on the
  -- pattern path so matching can remain root-scoped.
  for _, pattern in ipairs(common.sorted_keys(raw)) do
    local filetype = raw[pattern]
    if type(filetype) == 'string' and filetype ~= '' then
      for _, expanded_pattern in ipairs(expand_braces(pattern)) do
        local normalized = normalize_path(expanded_pattern)
        local extension = extract_simple_extension_from_glob(normalized)
        local filename = extension == nil and extract_simple_filename_from_glob(normalized) or nil

        if extension then
          files_associations.extensions[extension] = filetype
        elseif filename then
          files_associations.filenames[filename] = filetype
        else
          table.insert(files_associations.patterns, {
            filetype = filetype,
            has_slash = normalized:find('/') ~= nil,
            path_pattern = glob_to_lua_pattern(normalized, false),
            raw = normalized,
          })
        end
      end
    else
      warn_ignored(('files.associations.%s'):format(pattern))
    end
  end

  table.sort(files_associations.patterns, function(left, right)
    if #left.raw == #right.raw then
      return left.raw > right.raw
    end

    return #left.raw > #right.raw
  end)

  return files_associations
end

---@param root string
---@return ProjectFilesAssociations
local function load_files_associations(root)
  if files_associations_cache[root] then
    return files_associations_cache[root]
  end

  local raw = vscode_settings.read(root)
  local files_associations = parse_files_associations(raw['files.associations'])
  files_associations_cache[root] = files_associations
  return files_associations
end

---@param path string
---@param root string
---@param association { filetype: string, has_slash: boolean, path_pattern: string, raw: string }
---@return boolean
local function pattern_matches_path(path, root, association)
  local normalized_path = normalize_path(path)
  local normalized_root = normalize_path(root)
  local prefix = normalized_root .. '/'

  if normalized_path:sub(1, #prefix) ~= prefix then
    return false
  end

  local relative = normalized_path:sub(#prefix + 1)
  if association.has_slash then
    return relative:match('^' .. association.path_pattern .. '$') ~= nil
  end

  return vim.fs.basename(relative):match('^' .. association.path_pattern .. '$') ~= nil
end

---@param path string
---@return string|nil
local function resolve_project_filetype(path)
  local root = project_json.find_root_for_path(path)
  if not root then
    return nil
  end

  local files_associations = load_files_associations(root)
  local basename = vim.fs.basename(normalize_path(path))

  local filename_filetype = files_associations.filenames[basename]
  if filename_filetype then
    return filename_filetype
  end

  for _, association in ipairs(files_associations.patterns) do
    if pattern_matches_path(path, root, association) then
      return association.filetype
    end
  end

  local extension = basename:match('%.([^.]+)$')
  if not extension then
    return nil
  end

  return files_associations.extensions[extension]
end

---@param bufnr integer
local function update_buffer_filetype_state(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    set_filetype_managed(bufnr, false)
    return
  end

  local project_filetype = resolve_project_filetype(name)
  set_filetype_managed(
    bufnr,
    project_filetype ~= nil and project_filetype == vim.bo[bufnr].filetype
  )
end

---@param path string
---@param resolver fun(files_associations: ProjectFilesAssociations): string|nil
---@return string|nil
local function resolve_filetype_from_files_associations(path, resolver)
  local root = project_json.find_root_for_path(path)
  if not root then
    return nil
  end

  return resolver(load_files_associations(root))
end

---@param vim_filetype_key 'extension'|'filename'
---@param association_key 'extensions'|'filenames'
---@param seen_entries table<string, boolean>
---@param files_associations ProjectFilesAssociations
local function register_literal_filetypes(
  vim_filetype_key,
  association_key,
  seen_entries,
  files_associations
)
  local mapping = {}

  for key in pairs(files_associations[association_key]) do
    if not seen_entries[key] then
      seen_entries[key] = true
      mapping[key] = function(path)
        return resolve_filetype_from_files_associations(path, function(files_associations)
          return files_associations[association_key][key]
        end)
      end
    end
  end

  if next(mapping) ~= nil then
    -- `vim.filetype.add()` installs global literal mappings, so each dispatcher
    -- re-checks the current root and returns nil outside matching projects.
    vim.filetype.add({ [vim_filetype_key] = mapping })
  end
end

---@param root string
---@return table<string, vim.filetype.mapping> }>
local function build_pattern_filetypes(root)
  local files_associations = load_files_associations(root)
  local patterns = {}
  local root_pattern = escape_lua_pattern(root)

  for _, association in ipairs(files_associations.patterns) do
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
local function register_pattern_filetypes(root)
  if type(root) ~= 'string' or root == '' then
    return
  end

  local current = build_pattern_filetypes(root)
  local previous = filetype_patterns_by_root[root] or {}
  local patterns = vim.deepcopy(current)

  for pattern in pairs(previous) do
    if current[pattern] == nil then
      -- `vim.filetype.add()` only overwrites existing entries. Registering a
      -- nil matcher lets reload remove stale project-local patterns.
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

---@param root string|nil
local function ensure_filetype_detection_for_root(root)
  if type(root) ~= 'string' or root == '' then
    return
  end

  local files_associations = load_files_associations(root)
  register_literal_filetypes('extension', 'extensions', filetype_extensions, files_associations)
  register_literal_filetypes('filename', 'filenames', filetype_filenames, files_associations)
  register_pattern_filetypes(root)
end

---@param path string
function M.ensure_filetype_detection_for_path(path)
  if type(path) ~= 'string' or path == '' then
    return
  end

  ensure_filetype_detection_for_root(project_json.find_root_for_path(path))
end

---@param bufnr integer
function M.redetect_filetype(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return
  end

  M.ensure_filetype_detection_for_path(name)

  local was_managed = is_filetype_managed(bufnr)
  local project_filetype = resolve_project_filetype(name)
  local detected, on_detect = vim.filetype.match({ buf = bufnr, filename = name })
  if detected and detected ~= vim.bo[bufnr].filetype then
    vim.bo[bufnr].filetype = detected
    if on_detect then
      on_detect(bufnr)
    end
  end

  if not detected and was_managed then
    vim.bo[bufnr].filetype = ''
  end

  set_filetype_managed(
    bufnr,
    detected ~= nil and project_filetype ~= nil and detected == project_filetype
  )
end

function M.invalidate()
  files_associations_cache = {}
end

local function ensure_path_filetype_detection(args)
  M.ensure_filetype_detection_for_path(args.file)
end

---@param group integer
function M.setup(group)
  vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
    group = group,
    callback = ensure_path_filetype_detection,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    callback = function(args)
      update_buffer_filetype_state(args.buf)
    end,
  })

  -- Seed cwd/argv roots up front so the first open in those projects sees the
  -- project-local filetype rules without waiting for a later reload.
  project_json.for_each_startup_root(ensure_filetype_detection_for_root)
end

return M
