return {
	"vhyrro/luarocks.nvim",
	priority = 1000,
	config = true,
	opts = {
		-- rocks = { "lua-curl", "nvim-nio", "mimetypes", "xml2lua" },
		-- TODO: need to build curl from source
		-- https://github.com/rest-nvim/rest.nvim/issues/335
		-- NOTE: luarocks hasn't yet supported additional command args for installation
		-- https://github.com/vhyrro/luarocks.nvim/issues/18
	},
}
