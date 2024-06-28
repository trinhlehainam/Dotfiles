return {
	"xvzc/chezmoi.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		require("chezmoi").setup({
			-- your configurations
			vim.filetype.add({
				filename = {
					["dot_env"] = "env",
					["dot_gitignore"] = "gitignore",
					["dot_bashrc"] = "sh",
					["dot_bash_profile"] = "sh",
					["dot_bash_logout"] = "sh",
					["dot_bash_history"] = "sh",
					["dot_bash_aliases"] = "sh",
					["dot_zshrc"] = "sh",
					["dot_tmux.conf"] = "tmux",
				},
			}),
		})

		local chezmoi_ext = require("telescope").load_extension("chezmoi")
		vim.keymap.set("n", "<leader>cz", chezmoi_ext.find_files, { desc = "[C]hezmoi Find Files" })
	end,
}
