local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.dapconfig.type = "codelldb"
M.dapconfig.configs = {
	{
		name = "Launch file",
		type = M.dapconfig.type,
		request = "launch",
		program = function()
			return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
		end,
		cwd = "${workspaceFolder}",
		stopOnEntry = false,
	},
}

M.lspconfig.server = "rust_analyzer"
M.lspconfig.setup = function(_, _)
	-- NOTE: rustaceanvim will automatically configure rust-analyzer
	-- empty mason "rust-analyzer" setup to avoid conflict with rustaceanvim
end

return M
