return {
	{
		"romgrk/barbar.nvim",
		dependencies = {
			"lewis6991/gitsigns.nvim", -- OPTIONAL: for git status
			"nvim-tree/nvim-web-devicons", -- OPTIONAL: for file icons
		},
		version = "^1.0.0", -- optional: only update when a new 1.x version is released
		config = function()
			vim.g.barbar_auto_setup = false
			require("barbar").setup({
				-- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
				animation = false,
				auto_hide = true,
			})

			vim.keymap.set("n", "b1", ":BufferGoto 1<CR>", { noremap = true, silent = true, desc = "Go to [B]uffer 1" })
			vim.keymap.set("n", "b2", ":BufferGoto 2<CR>", { noremap = true, silent = true, desc = "Go to [B]uffer 2" })
			vim.keymap.set("n", "b3", ":BufferGoto 3<CR>", { noremap = true, silent = true, desc = "Go to [B]uffer 3" })
			vim.keymap.set("n", "b4", ":BufferGoto 4<CR>", { noremap = true, silent = true, desc = "Go to [B]uffer 4" })
			vim.keymap.set(
				"n",
				"bj",
				":BufferPrevious<CR>",
				{ noremap = true, silent = true, desc = "[B]uffer [P]revious" }
			)
			vim.keymap.set("n", "bk", ":BufferNext<CR>", { noremap = true, silent = true, desc = "[B]uffer [N]ext" })
			vim.keymap.set("n", "bl", ":BufferLast<CR>", { noremap = true, silent = true, desc = "[B]uffer [L]ast" })
			vim.keymap.set("n", "bh", ":BufferFirst<CR>", { noremap = true, silent = true, desc = "[B]uffer [F]irst" })
			vim.keymap.set("n", "bc", ":BufferClose<CR>", { noremap = true, silent = true, desc = "[B]uffer [C]lose" })
		end,
	},
}
