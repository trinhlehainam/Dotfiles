return {
	"mrcjkb/rustaceanvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"mfussenegger/nvim-dap",
	},
	version = "^4", -- Recommended
	lazy = false, -- This plugin is already lazy
	config = function()
		---@type fun() | nil
		local rustaceanvim_setup = vim.tbl_get(require("configs.lsp").plugin_setups, "rust")

		if rustaceanvim_setup then
			rustaceanvim_setup()
		end
	end,
}
