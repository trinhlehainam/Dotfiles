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
M.lspconfig.use_setup = false

function rustaceanvim_config()
	local path = require("utils.path")

	vim.g.rustaceanvim = {
		-- Plugin configuration
		tools = {},
		-- LSP configuration
		server = {
			settings = {
				["rust-analyzer"] = {
					checkOnSave = {
						command = "clippy",
					},
				},
			},
			on_attach = function(_, bufnr)
				require("utils.lsp").on_attach(_, bufnr)

				local nmap = path.create_nmap(bufnr)
				local vmap = path.create_vmap(bufnr)
				nmap("<leader>ca", function()
					vim.cmd.RustLsp("codeAction")
				end, "[C]ode [A]ction")
				vmap("<leader>ca", function()
					vim.cmd.RustLsp("codeAction")
				end, "[C]ode [A]ction Groups")
			end,
			cmd = { path.RUST_ANALYZER_CMD },
		},
		-- DAP configuration
		dap = {
			adapter = {
				type = "server",
				port = "${port}",
				host = "127.0.0.1",
				executable = {
					command = path.CODELLDB_PATH,
					args = path.DAP_ADAPTER_ARGS,
				},
			},
		},
	}
end

M.config = rustaceanvim_config
return M
