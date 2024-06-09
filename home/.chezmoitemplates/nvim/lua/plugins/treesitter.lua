return { -- Highlight, edit, and navigate code
	"nvim-treesitter/nvim-treesitter",
	build = function()
		require("nvim-treesitter.install").update({ with_sync = true })()
	end,
	dependencies = {
		{ "nvim-treesitter/nvim-treesitter-textobjects" },
		{ "nushell/tree-sitter-nu" },
		-- TODO: some tree-sitter extension require manually install
		-- { "EmranMR/tree-sitter-blade" },
	},
}
