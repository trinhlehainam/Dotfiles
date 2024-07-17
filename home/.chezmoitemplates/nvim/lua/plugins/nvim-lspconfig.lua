local function set_lualsconfig_plugin()
	if vim.fn.has("nvim-0.10.0") == 0 then
		-- `neodev` configures Lua LSP for your Neovim config, runtime and plugins
		-- used for completion, annotations and signatures of Neovim apis
		return "folke/neodev.nvim"
	else
		return {
			{
				"folke/lazydev.nvim",
				ft = "lua", -- only load on lua files
				opts = {
					library = {
						-- See the configuration section for more details
						-- Load luvit types when the `vim.uv` word is found
						{ path = "luvit-meta/library", words = { "vim%.uv" } },
					},
				},
			},
			{ "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
		}
	end
end

return {
	"neovim/nvim-lspconfig",
	dependencies = {
		-- Automatically install LSPs to stdpath for neovim
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"hrsh7th/cmp-nvim-lsp",

		-- Useful status updates for LSP
		-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
		{ "j-hui/fidget.nvim", opts = {} },

		set_lualsconfig_plugin(),

		"SmiteshP/nvim-navic",
	},
	config = function()
		-- INFO: https://github.com/SmiteshP/nvim-navic?tab=readme-ov-file#-customise
		require("nvim-navic").setup({
			highlight = true,
		})
		require("configs.plugins.nvim-lspconfig")
	end,
}
