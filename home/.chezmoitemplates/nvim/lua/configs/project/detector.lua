require('configs.project.types')

local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'

---@type table<string, ProjectFilesAssociations>
local files_associations_cache = {}
---@type table<string, table<string, boolean>>
local filetype_patterns_by_root = {}
---@type table<string, boolean>
local filetype_extensions = {}
---@type table<string, boolean>
local filetype_filenames = {}

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
      local normalized = normalize_path(pattern)
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

  local raw = project_json.read_json(root, VSCODE_SETTINGS)
  local files_associations = parse_files_associations(raw['files.associations'])
  files_associations_cache[root] = files_associations
  return files_associations
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

---@param extensions table<string, string>
local function register_extension_filetypes(extensions)
  local mapping = {}

  for extension in pairs(extensions) do
    if not filetype_extensions[extension] then
      filetype_extensions[extension] = true
      mapping[extension] = function(path)
        return resolve_filetype_from_files_associations(path, function(files_associations)
          return files_associations.extensions[extension]
        end)
      end
    end
  end

  if next(mapping) ~= nil then
    -- `vim.filetype.add({ extension = ... })` is global, so each dispatcher
    -- re-checks the current root and returns nil outside matching projects.
    vim.filetype.add({ extension = mapping })
  end
end

---@param filenames table<string, string>
local function register_filename_filetypes(filenames)
  local mapping = {}

  for filename in pairs(filenames) do
    if not filetype_filenames[filename] then
      filetype_filenames[filename] = true
      mapping[filename] = function(path)
        return resolve_filetype_from_files_associations(path, function(files_associations)
          return files_associations.filenames[filename]
        end)
      end
    end
  end

  if next(mapping) ~= nil then
    vim.filetype.add({ filename = mapping })
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

---@param path string
function M.ensure_filetype_detection_for_path(path)
  if type(path) ~= 'string' or path == '' then
    return
  end

  local root = project_json.find_root_for_path(path)
  if not root then
    return
  end

  local files_associations = load_files_associations(root)
  register_extension_filetypes(files_associations.extensions)
  register_filename_filetypes(files_associations.filenames)
  register_pattern_filetypes(root)
end

---@param bufnr integer
function M.redetect_filetype(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return
  end

  M.ensure_filetype_detection_for_path(name)

  local detected, on_detect = vim.filetype.match({ buf = bufnr, filename = name })
  if detected and detected ~= vim.bo[bufnr].filetype then
    vim.bo[bufnr].filetype = detected
    if on_detect then
      on_detect(bufnr)
    end
  end
end

local function register_startup_filetype_detection()
  -- Startup file detection happens before later buffer events, so seed the
  -- cwd and CLI file arguments up front.
  M.ensure_filetype_detection_for_path(vim.uv.cwd() or vim.fn.getcwd())

  for _, arg in ipairs(vim.fn.argv()) do
    if type(arg) == 'string' and arg ~= '' and arg ~= '-' then
      M.ensure_filetype_detection_for_path(vim.fn.fnamemodify(arg, ':p'))
    end
  end
end

function M.invalidate()
  files_associations_cache = {}
end

local function ensure_path_filetype_detection(args)
  M.ensure_filetype_detection_for_path(args.file)
end

---@param group integer
function M.setup(group)
  vim.api.nvim_create_autocmd('BufReadPre', {
    group = group,
    callback = ensure_path_filetype_detection,
  })

  vim.api.nvim_create_autocmd('BufNewFile', {
    group = group,
    callback = ensure_path_filetype_detection,
  })

  register_startup_filetype_detection()
end

return M
