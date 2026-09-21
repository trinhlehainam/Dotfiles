local common = require('utils.common')
local log = require('utils.log')
local project_json = require('configs.project.json')
local vscode_settings = require('configs.project.vscode_settings')

local M = {}

local TITLE = 'project-settings'
local VSCODE_SETTINGS = '.vscode/settings.json'
local BUFFER_FILETYPE_MANAGED_KEY = 'project_settings_filetype_managed'

---@type table<string, dotfiles.project.FilesAssociationPattern[]>
local files_associations_cache = {}

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

---@param key string
local function warn_ignored(key)
  log.warn(('Ignored unsupported key "%s" in %s'):format(key, VSCODE_SETTINGS), TITLE)
end

---@param glob string
---@return integer
local function association_priority(glob)
  -- Preserve exact basename > other glob > simple extension precedence.
  if not glob:find('[/*?%[%]{}]') then
    return 3
  end
  if glob:match('^%*%.[^.*?%[%]{}/]+$') then
    return 1
  end
  return 2
end

---@param root string
---@return dotfiles.project.FilesAssociationPattern[]
local function load_files_associations(root)
  if files_associations_cache[root] then
    return files_associations_cache[root]
  end

  local raw = vscode_settings.read(root)['files.associations']
  local associations = {}
  if raw ~= nil and type(raw) ~= 'table' then
    warn_ignored('files.associations')
  elseif type(raw) == 'table' then
    for _, glob in ipairs(common.sorted_keys(raw)) do
      local filetype = raw[glob]
      if type(glob) == 'string' and type(filetype) == 'string' and filetype ~= '' then
        local normalized = glob:gsub('\\', '/')
        local ok, matcher = pcall(vim.glob.to_lpeg, normalized)
        if ok and matcher then
          table.insert(associations, {
            filetype = filetype,
            has_slash = normalized:find('/') ~= nil,
            matcher = matcher,
            raw = normalized,
            priority = association_priority(normalized),
          })
        else
          warn_ignored('files.associations.' .. glob)
        end
      else
        warn_ignored('files.associations.' .. tostring(glob))
      end
    end
  end

  table.sort(associations, function(left, right)
    if left.priority ~= right.priority then
      return left.priority > right.priority
    end
    if #left.raw ~= #right.raw then
      return #left.raw > #right.raw
    end
    return left.raw > right.raw
  end)
  files_associations_cache[root] = associations
  return associations
end

---@param path string
---@return string|nil
local function resolve_project_filetype(path)
  local root = project_json.find_root_for_path(path)
  if not root then
    return nil
  end

  local relative = vim.fs.relpath(root, path)
  if not relative then
    return nil
  end
  relative = relative:gsub('\\', '/')
  local basename = vim.fs.basename(relative)
  for _, association in ipairs(load_files_associations(root)) do
    local candidate = association.has_slash and relative or basename
    if association.matcher:match(candidate) then
      return association.filetype
    end
  end
end

---@param bufnr integer
local function update_buffer_filetype_state(bufnr)
  local project_filetype = resolve_project_filetype(vim.api.nvim_buf_get_name(bufnr))
  set_filetype_managed(
    bufnr,
    project_filetype ~= nil and project_filetype == vim.bo[bufnr].filetype
  )
end

---@param bufnr integer
function M.redetect_filetype(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return
  end

  local project_filetype = resolve_project_filetype(name)
  if not project_filetype and not is_filetype_managed(bufnr) then
    return
  end

  local detected, on_detect = project_filetype, nil
  if not detected then
    detected, on_detect = vim.filetype.match({ buf = bufnr, filename = name })
  end
  if on_detect then
    on_detect(bufnr)
  end
  if vim.bo[bufnr].filetype ~= (detected or '') then
    vim.bo[bufnr].filetype = detected or ''
  end
  set_filetype_managed(bufnr, project_filetype ~= nil)
end

function M.invalidate()
  files_associations_cache = {}
end

---@param group integer
function M.setup(group)
  -- A single dynamic matcher leaves builtin extension/filename mappings intact
  -- and discovers settings even for the first new file in a project.
  vim.filetype.add({
    pattern = {
      ['.*'] = { resolve_project_filetype, { priority = math.huge } },
    },
  })

  -- Builtin exact filename entries precede pattern matchers, so apply project
  -- associations after detection as well (for example, CMakeLists.txt).
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    group = group,
    callback = function(args)
      M.redetect_filetype(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    callback = function(args)
      update_buffer_filetype_state(args.buf)
    end,
  })
end

return M
