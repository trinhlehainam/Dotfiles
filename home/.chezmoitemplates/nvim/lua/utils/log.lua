local levels = vim.log.levels

local TITLE = 'Nvim Dotfiles'

---@param level number
---@param msg string
---@param title? string
local function log(level, msg, title)
  title = title or TITLE
  vim.schedule(function()
    -- package.loaded is Lua's module cache table (see Lua 5.1 manual §5.3)
    -- When require('notify') is called, the module is cached in package.loaded['notify']
    -- nvim-notify overrides vim.notify and supports opts.title
    -- If not loaded yet, default vim.notify ignores opts, so prepend title to message
    if package.loaded['notify'] then
      vim.notify(msg, level, { title = title })
      return
    end

    if level == levels.ERROR then
      vim.notify(('[%s] %s'):format(title, msg), level)
    else
      vim.print(('[%s] %s'):format(title, msg))
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
