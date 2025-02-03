local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

-- INFO: https://github.com/uros-5/jinja-lsp?tab=readme-ov-file#configuration
-- INFO: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jinja_lsp
vim.filetype.add({
	extension = {
		jinja = "jinja",
		jinja2 = "jinja",
		j2 = "jinja",
	},
})

M.lspconfigs = { LspConfig:new("jinja_lsp") }

return M
