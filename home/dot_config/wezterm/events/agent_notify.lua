local wezterm = require('wezterm') ---@type Wezterm

-- Machine-local dedup using filesystem markers under $XDG_RUNTIME_DIR.
-- Each notification gets an atomic mkdir marker keyed by notification id.
-- First WezTerm process (or window) to create the marker shows the toast;
-- later attempts find the directory already exists and skip.

local MARKER_DIR = (os.getenv('XDG_RUNTIME_DIR') or '/tmp')
  .. '/agent-notify'

--- Ensure the marker directory exists.
local function ensure_marker_dir()
  pcall(wezterm.run_child_process, { 'mkdir', '-p', MARKER_DIR })
end

--- Prune marker directories older than 60 seconds (lazy cleanup).
local function prune_old_markers()
  pcall(wezterm.run_child_process, {
    'find', MARKER_DIR, '-mindepth', '1', '-maxdepth', '1',
    '-type', 'd', '-mmin', '+1', '-exec', 'rm', '-rf', '{}', '+',
  })
end

--- Try to atomically claim a notification id. Returns true if this is the
--- first claim (caller should show the toast).
local function try_claim(id)
  -- mkdir without -p fails atomically if the directory already exists
  local ok, success = pcall(wezterm.run_child_process, {
    'mkdir', MARKER_DIR .. '/' .. id,
  })
  return ok and success
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

    -- Machine-local atomic dedup
    if not try_claim(id) then
      return
    end

    window:toast_notification(title, body or '', nil, 4000)
  end)

  -- Ensure marker directory exists at startup
  ensure_marker_dir()
end
