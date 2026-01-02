local levels = vim.log.levels

local TITLE = 'Nvim Dotfiles'

-- Cached nvim-notify module, nil until first successful load
local notify_plugin = nil

--- Get nvim-notify module with caching
--- On first successful load, overrides vim.notify immediately since
--- module load timing may differ from nvim-notify's own override timing
---@return table|nil
local function get_notify()
  if notify_plugin then
    return notify_plugin
  end

  local ok, notify = pcall(require, 'notify')
  if ok then
    notify_plugin = notify
    vim.notify = notify_plugin
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
    local notify = get_notify()
    if notify then
      notify(msg, level, { title = title })
    else
      vim.notify(('[%s] %s'):format(title, msg), level)
    end
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
