local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = ""
M.lspconfig.use_setup = false

M.after_lspconfig = function()
	-- Check nu command is excutable
	if vim.fn.executable("nu") == 0 then
		require("utils.log").error("Nushell is not installed")
		return
	end

	local on_attach = require("utils.lsp").on_attach
	local capabilities = require("utils.lsp").get_cmp_capabilities()
	require("lspconfig").nushell.setup({
		capabilities = capabilities,
		on_attach = on_attach,
	})
end

return M
