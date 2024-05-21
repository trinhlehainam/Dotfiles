local levels = vim.log.levels

---@return fun(message: string)
local notify_fn = function(level)
	return
	---@param message string
	function(message)
		vim.notify(message, level, { title = "Nvim Dotfiles" })
	end
end

local M = {}
M.debug = notify_fn(levels.DEBUG)
M.info = notify_fn(levels.INFO)
M.warn = notify_fn(levels.WARN)
M.error = notify_fn(levels.ERROR)

return M
