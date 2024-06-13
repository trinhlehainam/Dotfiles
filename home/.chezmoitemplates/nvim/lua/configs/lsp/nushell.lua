local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

-- NOTE: https://github.com/nushell/nu_scripts

-- TODO: need to fix treesitter reinstall at startup
-- M.treesitter.filetypes = { "nu" }

M.lspconfig.server = ""
M.lspconfig.use_masonlsp_setup = false

M.after_masonlsp_setup = function()
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
