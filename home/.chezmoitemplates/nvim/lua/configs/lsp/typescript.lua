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

	-- If you are using mason.nvim, you can get the ts_plugin_path like this
	-- local hasmason, registry = pcall(require, "mason-registry")
	--
	-- if not hastools and not hasmason then
	-- 	log.error("mason.nvim is not installed")
	-- 	return
	-- end
	--
	-- local vue_language_server_path = registry.get_package("vue-language-server"):get_install_path()
	-- 	.. "/node_modules/@vue/language-server"

	-- {
	-- 	name = "@vue/typescript-plugin",
	-- 	location = vue_language_server_path,
	-- 	languages = { "vue" },
	-- },

	local hastools, typescripttools = pcall(require, "typescript-tools")

	if not hastools then
		log.error("typescript-tools is not installed")
		return
	end

	typescripttools.setup({
		on_attach = function(_, bufnr)
			require("utils.lsp").on_attach(_, bufnr)
		end,
		handlers = {},
		settings = {
			tsserver_plugins = {
				"@vue/typescript-plugin",
			},
		},
	})
end

M.config = typescripttools_config

return M
