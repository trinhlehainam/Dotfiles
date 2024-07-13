return {
	"m4xshen/hardtime.nvim",
	dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
	opts = {
		-- Add "oil" to the disabled_filetypes
		disabled_filetypes = {
			"qf",
			"netrw",
			"NvimTree",
			"neo-tree",
			"lazy",
			"mason",
			"oil",
			"trouble",
			"dbui",
			"dbout",
			"dapui_scopes",
			"dapui_breakpoints",
			"dapui_stacks",
			"dapui_watches",
			"dapui_console",
			"dapui_terminal",
			"dapui_repl",
		},
	},
}
