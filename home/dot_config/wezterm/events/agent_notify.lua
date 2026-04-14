local wezterm = require('wezterm') ---@type Wezterm

-- TTL dedup cache keyed by title|body; shared across all panes in this WezTerm
-- process, giving machine-level deduplication.
local notify_cache = {} ---@type table<string, number>
local TTL_SECONDS = 3

return function()
  wezterm.on('user-var-changed', function(window, _pane, name, value)
    if name ~= 'AGENT_NOTIFY' then
      return
    end

    -- Lazy prune expired entries
    local now = os.time()
    for k, expiry in pairs(notify_cache) do
      if expiry <= now then
        notify_cache[k] = nil
      end
    end

    -- WezTerm auto-decodes base64 from OSC 1337 SetUserVar before passing
    -- value to this handler, so value is already the JSON payload string.
    local ok, parsed = pcall(wezterm.json_parse, value)
    if not ok or type(parsed) ~= 'table' then
      return
    end

    local title = parsed.t
    local body = parsed.b
    if not title then
      return
    end

    local cache_key = title .. '|' .. (body or '')

    -- Suppress duplicate within TTL window
    if notify_cache[cache_key] then
      return
    end

    notify_cache[cache_key] = now + TTL_SECONDS
    window:toast_notification(title, body or '', nil, 4000)
  end)
end
