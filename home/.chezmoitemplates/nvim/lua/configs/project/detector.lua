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

---@class ProjectFiletypeAssociations
---@field extensions table<string, string>
---@field filenames table<string, string>
---@field patterns ProjectPatternAssociation[]

---@type table<string, ProjectFiletypeAssociations>
local association_cache = {}
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

---@return ProjectFiletypeAssociations
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

---@param raw any
---@return ProjectFiletypeAssociations
local function parse_associations(raw)
  local associations = empty_associations()

  if raw == nil then
    return associations
  end

  if type(raw) ~= 'table' then
    warn_ignored('files.associations')
    return associations
  end

  -- Lower exact `*.ext` and exact basename entries into Neovim's fast
  -- extension/filename tables. Path-aware and glob-style rules stay on the
  -- pattern path so matching can remain root-scoped.
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

---@param root string
---@return ProjectFiletypeAssociations
local function load_associations(root)
  if association_cache[root] then
    return association_cache[root]
  end

  local raw = project_json.read_json(root, VSCODE_SETTINGS)
  local associations = parse_associations(raw['files.associations'])
  association_cache[root] = associations
  return associations
end

---@param path string
---@param resolver fun(associations: ProjectFiletypeAssociations): string|nil
---@return string|nil
local function resolve_filetype_for_path(path, resolver)
  local root = project_json.find_root_for_path(path)
  if not root then
    return nil
  end

  return resolver(load_associations(root))
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
    -- `vim.filetype.add({ extension = ... })` is global, so each dispatcher
    -- re-checks the current root and returns nil outside matching projects.
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
  local associations = load_associations(root)
  local patterns = {}
  local root_pattern = escape_lua_pattern(root)

  for _, association in ipairs(associations.patterns) do
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
function M.ensure_for_path(path)
  if type(path) ~= 'string' or path == '' then
    return
  end

  local root = project_json.find_root_for_path(path)
  if not root then
    return
  end

  local associations = load_associations(root)
  register_filetype_extensions(associations.extensions)
  register_filetype_filenames(associations.filenames)
  register_filetype_patterns(root)
end

---@param bufnr integer
function M.redetect(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return
  end

  M.ensure_for_path(name)

  local detected, on_detect = vim.filetype.match({ buf = bufnr, filename = name })
  if detected and detected ~= vim.bo[bufnr].filetype then
    vim.bo[bufnr].filetype = detected
    if on_detect then
      on_detect(bufnr)
    end
  end
end

local function register_startup_mappings()
  -- Startup file detection happens before later buffer events, so seed the
  -- cwd and CLI file arguments up front.
  M.ensure_for_path(vim.uv.cwd() or vim.fn.getcwd())

  for _, arg in ipairs(vim.fn.argv()) do
    if type(arg) == 'string' and arg ~= '' and arg ~= '-' then
      M.ensure_for_path(vim.fn.fnamemodify(arg, ':p'))
    end
  end
end

function M.invalidate()
  association_cache = {}
end

---@param group integer
function M.setup(group)
  vim.api.nvim_create_autocmd('BufReadPre', {
    group = group,
    callback = function(args)
      M.ensure_for_path(args.file)
    end,
  })

  vim.api.nvim_create_autocmd('BufNewFile', {
    group = group,
    callback = function(args)
      M.ensure_for_path(args.file)
    end,
  })

  register_startup_mappings()
end

return M
