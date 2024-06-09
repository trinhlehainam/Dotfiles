local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "rust" }

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
M.lspconfig.use_masonlsp_setup = false

local common = require("utils.common")

---@param rust_analyzer_pkg_path string
---@return string
local function rust_analyzer_exec(rust_analyzer_pkg_path)
	if common.IS_WINDOWS then
		return rust_analyzer_pkg_path .. "/rust-analyzer.exe"
	else
		return rust_analyzer_pkg_path .. "/rust-analyzer"
	end
end

---@param mason_path string
---@param codelldb_pkg_path string
---@return string
local function codelldb_exec(mason_path, codelldb_pkg_path)
	if common.IS_WINDOWS then
		return mason_path .. "bin/" .. "codelldb.cmd"
	else
		return codelldb_pkg_path .. "extension/adapter/codelldb"
	end
end

---@param codelldb_pkg_path string
---@return string
local function liblldb_path(codelldb_pkg_path)
	if common.IS_WINDOWS then
		return ""
	else
		return codelldb_pkg_path .. "extension/lldb/lib/liblldb.so"
	end
end

---@param codelldb_pkg_path string
---@return string[]
local function dap_adapter_agrs(codelldb_pkg_path)
	if common.IS_WINDOWS then
		return { "--port", "${port}" }
	else
		return { "--liblldb", liblldb_path(codelldb_pkg_path), "--port", "${port}" }
	end
end

local function rustaceanvim_config()
	local log = require("utils.log")
	local hasrustaceanvim, _ = pcall(require, "rustaceanvim")

	if not hasrustaceanvim then
		log.error("rustaceanvim is not installed")
		return
	end

	local mason_utils = require("utils.mason")
	if not mason_utils.has_mason() then
		log.error("mason.nvim is not installed")
		return
	end

	local mason_path = mason_utils.get_mason_path()
	local rust_analyzer_path = mason_utils.get_mason_package_path("rust-analyzer")
	local codelldb_path = mason_utils.get_mason_package_path("codelldb")

	if not rust_analyzer_path then
		log.error("rust-analyzer is not installed in mason package")
		return
	end

	if not codelldb_path then
		log.error("codelldb is not installed in mason package")
		return
	end

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

				local nmap = common.create_nmap(bufnr)
				local vmap = common.create_vmap(bufnr)
				nmap("<leader>ca", function()
					vim.cmd.RustLsp("codeAction")
				end, "[C]ode [A]ction")
				vmap("<leader>ca", function()
					vim.cmd.RustLsp("codeAction")
				end, "[C]ode [A]ction Groups")
			end,
			cmd = { rust_analyzer_exec(rust_analyzer_path) },
		},
		-- DAP configuration
		dap = {
			adapter = {
				type = "server",
				port = "${port}",
				host = "127.0.0.1",
				executable = {
					command = codelldb_exec(mason_path, codelldb_path),
					args = dap_adapter_agrs(codelldb_path),
				},
			},
		},
	}

	local hasneotest, neotest = pcall(require, "neotest")

	-- NOTE: may need a standalone lsp config for neotest
	if not hasneotest then
		log.error("neotest is not installed")
		return
	end

	neotest.setup({
		adapters = {
			require("rustaceanvim.neotest"),
		},
	})
end

M.after_masonlsp_setup = rustaceanvim_config
return M
