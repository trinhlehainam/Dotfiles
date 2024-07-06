local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "go", "gomod", "gowork", "gotmpl" }

-- NOTE: ruff is an running server that watching python files
M.formatterconfig.servers = { "gofumpt", "goimports-reviser", "golines" }
M.formatterconfig.formatters_by_ft = {
	go = { "gofumpt", "goimports-reviser", "golines" },
}

-- INFO: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
-- INFO: https://github.com/golang/tools/blob/master/gopls/doc/vim.md#configuration
local gopls = LspConfig:new("gopls")
gopls.setup = function(capabilities, on_attach)
	require("lspconfig")[gopls.server].setup({
		capabilities = capabilities,
		on_attach = on_attach,
	})
end

-- NOTE: golangci-lint-langserver requires golangci-lint to be installed
M.linterconfig.servers = { "golangci-lint" }
-- INFO: https://github.com/nametake/golangci-lint-langserver?tab=readme-ov-file#configuration-for-nvim-lspconfig
local golangci_lint_ls = LspConfig:new("golangci_lint_ls")
golangci_lint_ls.setup = function(_, _)
	require("lspconfig")[golangci_lint_ls.server].setup({})
end

M.lspconfigs = { gopls, golangci_lint_ls }

M.dapconfig.type = "delve"

M.dapconfig.setup = function()
	local log = require("utils.log")

	local delve_path = require("utils.mason").get_mason_package_path(M.dapconfig.type)
	if type(delve_path) ~= "string" or delve_path == "" then
		log.error("nvim-dap-python is not installed")
		return
	end

	local has_dapgo, dapgo = pcall(require, "dap-go")
	if not has_dapgo then
		log.error("nvim-dap-python is not installed")
		return
	end

	local function get_executable_path()
		if require("utils.common").IS_WINDOWS then
			return delve_path .. "/dlv.exe"
		end
		return delve_path .. "/dlv"
	end
	-- INFO: https://github.com/leoluz/nvim-dap-go?tab=readme-ov-file#configuring
	dapgo.setup({
		delve = {
			path = get_executable_path(),
		},
	})
end

return M
