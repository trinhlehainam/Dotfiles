local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "css" }
M.lspconfig.server = "cssls"

return M
