local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "volar"
M.lspconfig.use_setup = false

return M
