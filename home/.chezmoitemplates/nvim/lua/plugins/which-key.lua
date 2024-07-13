return { -- Useful plugin to show you pending keybinds.
	"folke/which-key.nvim",
	event = "VimEnter",
	config = function()
		require("which-key").setup({})

		-- TODO: create which-key setup to each plugin-in and automatically register
		local wk = require("which-key")
		wk.add({
			{
				mode = "v",
				{
					"<leader>ss",
					function()
						require("nvim-silicon").shoot()
					end,
					desc = "Create code screenshot",
				},
				{
					"<leader>sf",
					function()
						require("nvim-silicon").file()
					end,
					desc = "Save code screenshot as file",
				},
				{
					"<leader>sc",
					function()
						require("nvim-silicon").clip()
					end,
					desc = "Copy code screenshot to clipboard",
				},
			},
		})
	end,
}
