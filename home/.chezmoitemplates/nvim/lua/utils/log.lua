local levels = vim.log.levels

local TITLE = 'Nvim Dotfiles'

-- Cache for nvim-notify module
-- nil = not yet available, once found it's cached for all future calls
local notify_plugin = nil

--- Attempts to get nvim-notify module, caching on success
--- Uses pcall for safe loading - retries on each call until module is available
---@return table|nil notify module or nil if not available
local function get_notify()
  if notify_plugin then
    return notify_plugin
  end

  local ok, notify = pcall(require, 'notify')
  if ok then
    notify_plugin = notify
    return notify_plugin
  end

  return nil
end

---@param level number
---@param msg string
---@param title? string
local function log(level, msg, title)
  title = title or TITLE
  vim.schedule(function()
    -- nvim-notify supports opts.title for styled notifications
    -- If not loaded yet, fallback to default vim.notify with title prepended
    if get_notify() then
      vim.notify(msg, level, { title = title })
      return
    end

    vim.notify(('[%s] %s'):format(title, msg), level)
  end)
end

return {
  debug = function(msg, title)
    log(levels.DEBUG, msg, title)
  end,
  info = function(msg, title)
    log(levels.INFO, msg, title)
  end,
  warn = function(msg, title)
    log(levels.WARN, msg, title)
  end,
  error = function(msg, title)
    log(levels.ERROR, msg, title)
  end,
}
