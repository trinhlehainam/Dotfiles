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

M.linterconfig.servers = { "ruff" }
M.linterconfig.linters_by_ft = {
	python = { "ruff" },
}

-- TODO: allow configure multiple lsp servers
local pyright = LspConfig:new("pyright")
pyright.use_masonlsp_setup = false
M.lspconfigs = { pyright }

M.dapconfig.type = "python"

local function python_lsp_setup()
	local log = require("utils.log")

	local hasmason, registry = pcall(require, "mason-registry")
	local haslspconfig, lspconfig = pcall(require, "lspconfig")

	if not hasmason then
		log.error("mason.nvim is not installed")
		return
	end

	if not haslspconfig then
		log.error("lspconfig is not installed")
		return
	end

	local debugpy_pkg = registry.get_package("debugpy")
	if not debugpy_pkg:is_installed() then
		log.error("debugpy is not installed")
		return
	end

	local lsp_utils = require("utils.lsp")
	local capabilities = lsp_utils.capabilities
	local on_attach = lsp_utils.on_attach
	lspconfig[pyright.server].setup({
		capabilities = capabilities,
		on_attach = on_attach,
	})

	local has_dappython, dappython = pcall(require, "dap-python")
	if not has_dappython then
		log.error("nvim-dap-python is not installed")
		return
	end

	local debugpy_path = debugpy_pkg:get_install_path() .. "/venv/bin/python"
	dappython.setup(debugpy_path)
end

M.after_masonlsp_setup = python_lsp_setup

return M
