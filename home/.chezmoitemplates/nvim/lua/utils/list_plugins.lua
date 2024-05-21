-- Print loaded Lua modules
print("Loaded Lua Modules:")
for k, _ in pairs(package.loaded) do
	print(k)
end

-- Print plugins managed by lazy.nvim
local ok, lazy = pcall(require, "lazy")
if ok then
	print("\nPlugins managed by lazy.nvim:")
	local plugins = lazy.plugins()
	for _, plugin in ipairs(plugins) do
		print(plugin.name)
	end
else
	print("lazy.nvim is not installed or not found")
end

-- Print runtime paths
print("\nRuntime Paths:")
local rtp = vim.o.runtimepath
for path in string.gmatch(rtp, "[^,]+") do
	print(path)
end
