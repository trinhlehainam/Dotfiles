local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.formatterconfig.servers = { "prettierd" }
M.formatterconfig.formatters_by_ft = {
	javascript = { "prettierd" },
	typescript = { "prettierd" },
	javascriptreact = { "prettierd" },
	typescriptreact = { "prettierd" },
	vue = { "prettierd" },
}

M.linterconfig.servers = { "eslint_d" }
M.linterconfig.linters_by_ft = {
	javascript = { "eslint_d" },
	typescript = { "eslint_d" },
	javascriptreact = { "eslint_d" },
	typescriptreact = { "eslint_d" },
	vue = { "eslint_d" },
}

---@param capabilities lsp.ClientCapabilities
---@param on_attach fun(client: lsp.Client, bufnr: integer)
local function setup(capabilities, on_attach)
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

	local volar_pkg = registry.get_package("vue-language-server")
	if not volar_pkg:is_installed() then
		log.error("vue-language-server is not installed")
		return
	end

	--Ref:
	--	- https://github.com/vuejs/language-tools?tab=readme-ov-file#community-integration
	--	- https://vuejs.org/guide/typescript/overview.html#volar-takeover-mode
	--	- https://github.com/mason-org/mason-registry/issues/5064
	--	- https://stackoverflow.com/a/59788563
	local vue_language_server_path = volar_pkg:get_install_path() .. "/node_modules/@vue/language-server"

	lspconfig.vtsls.setup({
		filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
		capabilities = capabilities,
		on_attach = on_attach,
		settings = {
			vtsls = {
				tsserver = {
					globalPlugins = {
						{
							name = "@vue/typescript-plugin",
							location = vue_language_server_path,
							languages = { "vue" },
							configNamespace = "typescript",
							enableForWorkspaceTypeScriptVersions = true,
						},
					},
				},
			},
		},
	})
end

M.lspconfig.server = "vtsls"
M.lspconfig.use_setup = true
M.lspconfig.setup = setup

return M
