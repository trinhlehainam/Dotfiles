local levels = vim.log.levels

local TITLE = 'Nvim Dotfiles'

-- Cached nvim-notify module, nil until first successful load
local notify_plugin = nil

--- Get nvim-notify module with caching
--- On first successful load, overrides vim.notify immediately since
--- module load timing may differ from nvim-notify's own override timing
---@return notify|nil
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
