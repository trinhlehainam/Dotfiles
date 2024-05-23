return {
	"folke/todo-comments.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		require("todo-comments").setup({
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		})

		vim.keymap.set("n", "<leader>ftd", ":TodoTelescope<CR>", { desc = "[F]ind [T]o[d]o" })
	end,
}
