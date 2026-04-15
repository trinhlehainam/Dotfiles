local wezterm = require('wezterm') ---@type Wezterm
local platform = require('utils.platform')

-- Machine-local dedup uses per-notification marker directories.
--
-- Portable Lua file APIs do not offer exclusive-create semantics, so a plain
-- `io.open(..., 'w')` claim is racy across multiple WezTerm processes.
-- We instead use platform-specific `mkdir` for atomic claims. Cleanup is based
-- on the timestamp prefix already embedded in notification ids.

local sep = package.config:sub(1, 1)

local function first_non_empty(...)
  for i = 1, select('#', ...) do
    local value = select(i, ...)
    if type(value) == 'string' and value ~= '' then
      return value
    end
  end
  return nil
end

local function marker_root()
  if platform.is_win then
    return first_non_empty(os.getenv('TEMP'), os.getenv('TMP'), wezterm.home_dir)
  end

  return first_non_empty(os.getenv('XDG_RUNTIME_DIR'), os.getenv('TMPDIR'), '/tmp')
end

local MARKER_DIR = table.concat({ marker_root(), 'agent-notify' }, sep)
local MARKER_TTL = 60 -- seconds before lazy cleanup evicts old markers

---@param id string
---@return string
local function marker_key(id)
  local sanitized = tostring(id):gsub('[^%w%._%-]', '_')
  return sanitized ~= '' and sanitized or 'unknown'
end

---@param args string[]
---@return boolean
local function run_command(args)
  -- `run_child_process()` returns success=false for non-zero exit status and
  -- raises on spawn failure. `try_claim()` checks marker existence afterward to
  -- distinguish a lost race from infrastructure failure.
  local ok, success = pcall(wezterm.run_child_process, args)
  return ok and success
end

---@param path string
---@return boolean
local function mkdir_p(path)
  if platform.is_win then
    -- WezTerm Lua cannot call Win32 APIs directly, so Windows claims/removals go
    -- through `cmd.exe`. `/D` disables AutoRun side effects for this helper.
    return run_command({ 'cmd.exe', '/D', '/C', 'mkdir', path })
  end

  return run_command({ 'mkdir', '-p', path })
end

---@param path string
---@return boolean
local function mkdir_one(path)
  if platform.is_win then
    return run_command({ 'cmd.exe', '/D', '/C', 'mkdir', path })
  end

  return run_command({ 'mkdir', path })
end

---@param path string
---@return boolean
local function remove_empty_dir(path)
  if platform.is_win then
    return run_command({ 'cmd.exe', '/D', '/C', 'rmdir', path })
  end

  return os.remove(path) ~= nil
end

---@param id string
---@return string
local function claim_dir(id)
  return MARKER_DIR .. sep .. marker_key(id)
end

--- Ensure the marker directory exists.
local function ensure_marker_dir()
  mkdir_p(MARKER_DIR)
end

---@param path string
---@return string[]|nil
local function list_dir(path)
  local ok, entries = pcall(wezterm.read_dir, path)
  if not ok or type(entries) ~= 'table' then
    return nil
  end

  return entries
end

---@param dir string
---@return boolean
local function marker_exists(dir)
  return list_dir(dir) ~= nil
end

---@param dir string
---@return number|nil
local function marker_timestamp_ms(dir)
  local name = dir:match('([^/\\]+)$') or dir
  local prefix = name:match('^([0-9A-Za-z]+)%-')
  if not prefix then
    return nil
  end

  return tonumber(prefix, 36)
end

--- Prune marker directories older than MARKER_TTL seconds.
local function prune_old_markers()
  local cutoff_ms = (os.time() - MARKER_TTL) * 1000
  local dirs = list_dir(MARKER_DIR)
  if not dirs then
    return
  end

  for _, dir in ipairs(dirs) do
    local ts = marker_timestamp_ms(dir)
    if ts and ts < cutoff_ms then
      remove_empty_dir(dir)
    end
  end
end

--- Try to claim a notification id. Returns true if this process should show the
--- toast. On infrastructure failure, prefer showing the toast over dropping it.
---@param id string
---@return boolean
local function try_claim(id)
  ensure_marker_dir()

  local dir = claim_dir(id)
  if mkdir_one(dir) then
    return true
  end

  if marker_exists(dir) then
    return false
  end

  return true
end

return function()
  wezterm.on('user-var-changed', function(window, _, name, value)
    if name ~= 'AGENT_NOTIFY' then
      return
    end

    -- WezTerm auto-decodes base64 from OSC 1337 SetUserVar before passing
    -- value to this handler, so value is already the JSON payload string.
    local ok, parsed = pcall(wezterm.json_parse, value)
    if not ok or type(parsed) ~= 'table' then
      return
    end

    local id = parsed.id
    local title = parsed.t
    local body = parsed.b
    if not id or not title then
      return
    end

    -- Lazy prune old markers on each event
    prune_old_markers()

    -- Machine-local dedup
    if not try_claim(id) then
      return
    end

    window:toast_notification(title, body or '', nil, 4000)
  end)
end
