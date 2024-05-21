local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tailwindcss"
M.lspconfig.setup = function(_, _)
	-- NOTE: tailwind-tools will automatically configure tailwindcss in nvim-lspconfig
end

return M
