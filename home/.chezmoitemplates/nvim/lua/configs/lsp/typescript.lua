local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tsserver"
M.lspconfig.use_setup = false

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

local function typescripttools_config()
	local log = require("utils.log")

	local hasmason, registry = pcall(require, "mason-registry")
	local hastools, typescripttools = pcall(require, "typescript-tools")

	if not hastools and not hasmason then
		log.error("mason.nvim is not installed")
		return
	end

	local volar_pkg = registry.get_package("vue-language-server")
	if not volar_pkg:is_installed() then
		log.error("vue-language-server is not installed")
		return
	end

	--Ref: https://github.com/vuejs/language-tools?tab=readme-ov-file#community-integration
	local vue_language_server_path = volar_pkg:get_install_path() .. "/node_modules/@vue/language-server"

	if not hastools then
		log.error("typescript-tools is not installed")
		return
	end

	-- NOTE:
	--The parameters passed into the setup function are also passed to the standard nvim-lspconfig server setup,
	--allowing you to use the same settings here. But you can pass plugin-specific options through the settings parameter,
	--which defaults to:
	--Ref: https://github.com/pmizio/typescript-tools.nvim?tab=readme-ov-file#%EF%B8%8F-configuration
	typescripttools.setup({
		init_options = {
			plugins = {
				{
					name = "@vue/typescript-plugin",
					location = vue_language_server_path,
					languages = { "vue" },
				},
			},
		},
		on_attach = function(_, bufnr)
			require("utils.lsp").on_attach(_, bufnr)
		end,
	})
end

M.config = typescripttools_config

return M
