local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

-- NOTE: only use for install volar language server
M.lspconfig.server = "volar"
M.lspconfig.use_masonlsp_setup = false

return M
