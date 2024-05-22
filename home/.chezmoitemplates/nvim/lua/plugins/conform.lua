return { -- Formatter
	"stevearc/conform.nvim",
	lazy = false,
	keys = {
		{
			"<leader>fm",
			function()
				require("conform").format({ async = true, lsp_fallback = true })
			end,
			mode = "",
			desc = "[F]or[m]at buffer",
		},
	},
}
