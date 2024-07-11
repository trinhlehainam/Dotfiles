local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "rust", "toml" }

local common = require("utils.common")
local log = require("utils.log")
local mason_utils = require("utils.mason")

---@param mason_path string
---@return string
local function rust_analyzer_exec(mason_path)
	if common.IS_WINDOWS then
		return mason_path .. "bin/rust-analyzer.cmd"
	else
		return mason_path .. "bin/rust-analyzer"
	end
end

local rust_analyzer = LspConfig:new("rust_analyzer")
rust_analyzer.setup = function(_, on_attach)
	local hasrustaceanvim, _ = pcall(require, "rustaceanvim")

	if not hasrustaceanvim then
		log.error("rustaceanvim is not installed")
		return
	end

	local rust_analyzer_path = mason_utils.get_mason_package_path("rust-analyzer")

	if not rust_analyzer_path then
		log.error("rust-analyzer is not installed in mason package")
		return
	end

	if vim.g.rustaceanvim == nil then
		vim.g.rustaceanvim = {}
	end

	vim.g.rustaceanvim.server = {
		cmd = { rust_analyzer_exec(rust_analyzer_path) },
		settings = {
			["rust-analyzer"] = {
				checkOnSave = {
					command = "clippy",
				},
			},
		},
		on_attach = function(client, bufnr)
			on_attach(client, bufnr)

			local nmap = common.create_nmap(bufnr)
			local vmap = common.create_vmap(bufnr)
			nmap("<leader>ca", function()
				vim.cmd.RustLsp("codeAction")
			end, "[C]ode [A]ction")
			vmap("<leader>ca", function()
				vim.cmd.RustLsp("codeAction")
			end, "[C]ode [A]ction Groups")
		end,
	}
end
M.lspconfigs = { rust_analyzer }

---@param mason_path string
---@return string
local function codelldb_exec(mason_path)
	if common.IS_WINDOWS then
		return mason_path .. "bin/" .. "codelldb.cmd"
	else
		return mason_path .. "bin/" .. "codelldb"
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

M.dapconfig.type = "codelldb"
M.dapconfig.setup = function()
	local hasrustaceanvim, _ = pcall(require, "rustaceanvim")

	if not hasrustaceanvim then
		log.error("rustaceanvim is not installed")
		return
	end

	local mason_path = mason_utils.get_mason_path()
	local codelldb_path = mason_utils.get_mason_package_path("codelldb")

	if not codelldb_path then
		log.error("codelldb is not installed in mason package")
		return
	end

	if vim.g.rustaceanvim == nil then
		vim.g.rustaceanvim = {}
	end

	vim.g.rustaceanvim.dap = {
		adapter = {
			type = "server",
			port = "${port}",
			host = "127.0.0.1",
			executable = {
				command = codelldb_exec(mason_path),
				args = dap_adapter_agrs(codelldb_path),
			},
		},
	}
end

M.after_masonlsp_setup = function()
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

return M
