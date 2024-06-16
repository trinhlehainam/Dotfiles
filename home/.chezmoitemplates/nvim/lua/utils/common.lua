local M = {}

M.OS = vim.loop.os_uname().sysname
M.IS_MAC = M.OS == "Darwin"
M.IS_LINUX = M.OS == "Linux"
M.IS_WINDOWS = M.OS:find("Windows") and true or false
M.IS_WSL = M.IS_LINUX and vim.loop.os_uname().release:find("Microsoft") and true or false

---@param bufnr number
---@return fun(keys: string, func: function, desc: string)
function M.create_nmap(bufnr)
	return function(keys, func, desc)
		if desc then
			desc = "LSP: " .. desc
		end

		vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
	end
end

---@param bufnr number
---@return fun(keys: string, func: function, desc: string)
function M.create_vmap(bufnr)
	return function(keys, func, desc)
		if desc then
			desc = "LSP: " .. desc
		end

		vim.keymap.set("v", keys, func, { buffer = bufnr, desc = desc })
	end
end

---@param modname string
---@return string
function M.modname_to_dir_path(modname)
	local path = string.gsub(modname, "%.", "/")
	return vim.fn.stdpath("config") .. "/lua/" .. path
end

---@param directory string
---@param ignore_mods string[]
---@return table<string, any>
function M.load_mods_in_dir(directory, ignore_mods)
	local mods = {}
	local mods_dirname = string.match(directory, "/lua/(.-)/?$")
	for _, filename in ipairs(vim.fn.readdir(directory)) do
		if filename:match("%.lua$") then
			local modname = filename:match("^(.-)%.lua$")
			if not ignore_mods or not vim.tbl_contains(ignore_mods, modname) then
				mods[modname] = require(mods_dirname .. "." .. modname)
			end
		end
	end
	return mods
end

---@param modname string
---@param ignore_mods string[]
---@return table<string, any>
function M.load_mods(modname, ignore_mods)
	local mods_dir = M.modname_to_dir_path(modname)
	return M.load_mods_in_dir(mods_dir, ignore_mods)
end

-- Function to create a temporary file with a specific extension
--- @param extension string?
--- @return string
function M.create_temp_file(extension)
	-- Generate a temporary filename
	local temp_file = os.tmpname()

	if type(extension) == "nil" then
		return temp_file
	end

	-- Rename the file to have the desired extension
	local temp_file_with_extension = temp_file .. "." .. extension
	os.rename(temp_file, temp_file_with_extension)
	return temp_file_with_extension
end

return M
