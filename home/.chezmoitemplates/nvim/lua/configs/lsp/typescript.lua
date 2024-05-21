local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tsserver"
M.lspconfig.setup = function(_, _)
	-- NOTE: typescript-tools will automatically configure tsserver in nvim-lspconfig
end

return M
