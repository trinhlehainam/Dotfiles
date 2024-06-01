return {
	"folke/ts-comments.nvim",
	opts = {},
	event = "VeryLazy",
	enabled = not vim.version.range("<0.10.0"):has(vim.version()),
}
