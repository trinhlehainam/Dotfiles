return { -- Highlight, edit, and navigate code
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	dependencies = {
		{ "nvim-treesitter/nvim-treesitter-textobjects" },
		{ "nushell/tree-sitter-nu" },
		-- TODO: some tree-sitter extension require manually install
		-- { "EmranMR/tree-sitter-blade" },
	},
	config = function()
		require("configs.plugins.nvim-treesitter")
	end,
}
