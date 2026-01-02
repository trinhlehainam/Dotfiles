local levels = vim.log.levels

local TITLE = 'Nvim Dotfiles'

local get_notify = nil
do
  -- Cached nvim-notify module, nil until first successful load
  local _notify = nil

  --- Get nvim-notify module with caching
  --- Fetches and caches the notify implementation for use by callers.
  ---@return notify|nil
  get_notify = function()
    if _notify then
      return _notify
    end

    local ok, notify = pcall(require, 'notify')
    if ok then
      _notify = notify
      return _notify
    end

    return nil
  end
end

---@param level number
local function notify_fn(level)
  ---@param msg string
  ---@param title? string
  return function(msg, title)
    title = title or TITLE
    vim.schedule(function()
      local notify = get_notify()
      if notify then
        notify(msg, level, { title = title })
      else
        vim.notify(('[%s] %s'):format(title, msg), level)
      end
    end)
  end
end

return {
  debug = notify_fn(levels.DEBUG),
  info = notify_fn(levels.INFO),
  warn = notify_fn(levels.WARN),
  error = notify_fn(levels.ERROR),
}
