local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "tailwindcss"
M.lspconfig.use_setup = false

return M
