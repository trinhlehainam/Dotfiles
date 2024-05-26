local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "cssls"
M.lspconfig.use_setup = true

return M
