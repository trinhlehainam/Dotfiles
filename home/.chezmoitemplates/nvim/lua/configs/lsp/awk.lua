local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "awk" }

M.lspconfig.server = "awk_ls"

return M
