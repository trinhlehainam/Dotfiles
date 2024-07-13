local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "python" }

-- NOTE: ruff is an running server that watching python files
M.formatterconfig.servers = { "ruff" }
M.formatterconfig.formatters_by_ft = {
	python = {
		-- "ruff_fix", -- An extremely fast Python linter, written in Rust. Fix lint errors.
		"ruff_format", -- An extremely fast Python linter, written in Rust. Formatter subcommand.
		"ruff_organize_imports", -- An extremely fast Python linter, written in Rust. Organize imports.
	},
}

local pyright = LspConfig:new("pyright")
pyright.setup = function(capabilities, on_attach)
	require("lspconfig")[pyright.server].setup({
		capabilities = capabilities,
		on_attach = on_attach,
		settings = {
			pyright = {
				-- Using Ruff's import organizer
				disableOrganizeImports = true,
			},
			python = {
				analysis = {
					-- Ignore all files for analysis to exclusively use Ruff for linting
					ignore = { "*" },
				},
			},
		},
	})
end

local ruff = LspConfig:new("ruff")
-- Ruff configuration for Neovim
-- INFO: https://github.com/astral-sh/ruff/blob/main/crates/ruff_server/docs/setup/NEOVIM.md
ruff.setup = function(_, _)
	require("lspconfig")[ruff.server].setup({
		on_attach = function(client, _)
			if client.name == "ruff" then
				-- Disable hover in favor of Pyright
				client.server_capabilities.hoverProvider = false
			end
		end,
	})
end

M.lspconfigs = { pyright, ruff }

M.dapconfig.type = "python"
M.dapconfig.setup = function()
	local log = require("utils.log")

	local debugpy_path = require("utils.mason").get_mason_package_path("debugpy")

	if type(debugpy_path) ~= "string" or debugpy_path == "" then
		log.error("debugpy is not installed")
		return
	end

	local has_dappython, dappython = pcall(require, "dap-python")
	if not has_dappython then
		log.error("nvim-dap-python is not installed")
		return
	end

	local function get_debugpy_path()
		if vim.fn.has("win32") == 1 then
			return debugpy_path .. "/venv/Scripts/python.exe"
		else
			return debugpy_path .. "/venv/bin/python"
		end
	end
	dappython.setup(get_debugpy_path())
end

M.neotest_adapter_setup = function()
	local has_pytest, _ = pcall(require, "neotest-python")
	if not has_pytest then
		return {}
	end
	-- INFO: https://github.com/nvim-neotest/neotest-python?tab=readme-ov-file#neotest-python
	return require("neotest-python")
end

return M
