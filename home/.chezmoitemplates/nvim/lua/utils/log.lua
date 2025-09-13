local levels = vim.log.levels

-- Cache for notify plugin availability
local notify_plugin = nil
local notify_checked = false

-- Check and cache notify plugin availability
local function get_notify()
  if not notify_checked then
    notify_checked = true
    local ok, notify = pcall(require, 'notify')
    if ok then
      notify_plugin = notify
    end
  end
  return notify_plugin
end

---@param level number
---@return fun(message: string)
local notify_fn = function(level)
  return
  ---@param message string
  function(message)
    -- Use vim.schedule for non-blocking execution on next event loop iteration
    vim.schedule(function()
      local notify = get_notify()
      if notify then
        notify(message, level, { title = 'Nvim Dotfiles' })
      else
        -- Fallback to built-in vim.notify
        vim.notify(message, level)
      end
    end)
  end
end

local M = {}
M.debug = notify_fn(levels.DEBUG)
M.info = notify_fn(levels.INFO)
M.warn = notify_fn(levels.WARN)
M.error = notify_fn(levels.ERROR)

return M
