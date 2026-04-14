local wezterm = require('wezterm') ---@type Wezterm

-- Machine-local dedup using filesystem markers under $XDG_RUNTIME_DIR.
-- Each notification gets a marker file keyed by notification id.
-- First WezTerm process (or window) to create the marker shows the toast;
-- later attempts find the file already exists and skip.
--
-- All per-event operations use portable Lua io/os APIs — no POSIX shell
-- commands needed. Only the one-time marker directory creation uses
-- wezterm.run_child_process.

local MARKER_DIR = (os.getenv('XDG_RUNTIME_DIR') or '/tmp')
  .. '/agent-notify'

local MARKER_TTL = 60 -- seconds before lazy cleanup evicts old markers

--- Ensure the marker directory exists (one-time, at startup).
local function ensure_marker_dir()
  pcall(wezterm.run_child_process, { 'mkdir', '-p', MARKER_DIR })
end

--- Prune marker files older than MARKER_TTL seconds.
--- Uses wezterm.glob (portable) + os.remove (Lua built-in).
local function prune_old_markers()
  local now = os.time()
  local cutoff = now - MARKER_TTL
  local ok, files = pcall(wezterm.glob, MARKER_DIR .. '/*')
  if not ok or not files then
    return
  end
  for _, path in ipairs(files) do
    local f = io.open(path, 'r')
    if f then
      local ts = f:read('*n') -- read number (timestamp)
      f:close()
      if ts and ts < cutoff then
        os.remove(path)
      end
    end
  end
end

--- Try to claim a notification id. Returns true if this is the first claim.
--- Uses portable Lua io — no shell commands.
local function try_claim(id)
  local marker = MARKER_DIR .. '/' .. id
  -- Check if already claimed
  local f = io.open(marker, 'r')
  if f then
    f:close()
    return false -- already claimed
  end
  -- Claim: write current timestamp
  f = io.open(marker, 'w')
  if not f then
    return false -- could not create (dir missing?)
  end
  f:write(tostring(os.time()))
  f:close()
  return true
end

return function()
  wezterm.on('user-var-changed', function(window, _pane, name, value)
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

  -- Ensure marker directory exists at startup
  ensure_marker_dir()
end
