return {
	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"sindrets/diffview.nvim", -- optional - Diff integration

			"nvim-telescope/telescope.nvim", -- optional
		},
		config = function()
			local neogit = require("neogit")
			neogit.setup({
				mappings = {
					-- Setting any of these to `false` will disable the mapping.
					popup = {},
					status = {},
				},
			})

			local diffview = require("diffview")
			diffview.setup()

			vim.keymap.set("n", "<leader>gs", neogit.open, { desc = "[S]how [G]it", silent = true, noremap = true })
			vim.keymap.set(
				"n",
				"<leader>gc",
				":Neogit commit<CR>",
				{ desc = "[G]it [C]ommit", silent = true, noremap = true }
			)
			vim.keymap.set(
				"n",
				"<leader>gp",
				":Neogit pull<CR>",
				{ desc = "[G]it [P]ull", silent = true, noremap = true }
			)
			vim.keymap.set(
				"n",
				"<leader>gP",
				":Neogit push<CR>",
				{ desc = "[G]it [P]ush", silent = true, noremap = true }
			)
			vim.keymap.set(
				"n",
				"<leader>gb",
				":Telescope git_branches<CR>",
				{ desc = "[G]it [B]ranches", silent = true, noremap = true }
			)
		end,
	},
	-- 'tpope/vim-rhubarb',
	{
		-- Adds git releated signs to the gutter, as well as utilities for managing changes
		"lewis6991/gitsigns.nvim",
		opts = {
			-- See `:help gitsigns.txt`
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
		},
	},
	-- Github related plugins
	{
		"pwntester/octo.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			-- INFO: https://github.com/pwntester/octo.nvim?tab=readme-ov-file#-configuration
			require("octo").setup({
				enable_builtin = true,
				mappings = {
					submit_win = {
						-- NOTE: Octo default keymap '<C-a>' is conflicted with tmux prefix key
						approve_review = { lhs = "<C-e>", desc = "approve review" },
					},
				},
			})

			vim.keymap.set("n", "<leader>o", "<cmd>Octo<cr>", { desc = "[O]cto", silent = true, noremap = true })

			vim.treesitter.language.register("markdown", "octo")
		end,
	},
}
