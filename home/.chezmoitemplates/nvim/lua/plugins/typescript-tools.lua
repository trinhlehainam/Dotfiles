return {
	"pmizio/typescript-tools.nvim",
	requires = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
	config = function()
		require("typescript-tools").setup {
			on_attach = function(_, bufnr)
				require('utils.lsp').on_attach(_, bufnr)
			end,
			handlers = {},
			settings = {}
		}
	end,
}
