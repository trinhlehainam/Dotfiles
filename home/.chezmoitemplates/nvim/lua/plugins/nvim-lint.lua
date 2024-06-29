return { -- Linter
	"mfussenegger/nvim-lint",
	dependencies = { "williamboman/mason.nvim" },
	event = {
		"BufReadPre",
		"BufNewFile",
	},
	config = function()
		require("configs.plugins.nvim-lint")
	end,
}
