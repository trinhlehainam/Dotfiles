local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "yamlls"
M.lspconfig.use_setup = true

M.lspconfig.setup = function(capabilities, on_attach)
	require("lspconfig")[M.lspconfig.server].setup({
		-- NOTE: yaml.docker-compose has its own lsp config, not use yamlls
		-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#yamlls
		filetypes = { "yaml", "yaml.gitlab" },
		capabilities = capabilities,
		on_attach = on_attach,
		settings = {
			yaml = {
				schemaStore = {
					-- You must disable built-in schemaStore support if you want to use
					-- this plugin and its advanced options like `ignore`.
					enable = false,
					-- Avoid TypeError: Cannot read properties of undefined (reading 'length')
					url = "",
				},
				schemas = require("schemastore").yaml.schemas(),
			},
		},
	})
end

return M
