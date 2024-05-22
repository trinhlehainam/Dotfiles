return {
	"luckasRanarison/tailwind-tools.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		local lsp = require("tailwind-tools.lsp")
		require("tailwind-tools").setup({})
	end,
}
