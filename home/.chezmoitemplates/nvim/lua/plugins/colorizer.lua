return {
	"NvChad/nvim-colorizer.lua",
	config = function()
		require("colorizer").setup({
			filetypes = {
				"css",
				"javascript",
				"typescript",
				html = { mode = "foreground" },
			},
			user_default_options = {
				mode = "virtualtext",
			},
		})
	end,
}
