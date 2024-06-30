local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "vue" }

local volar = LspConfig:new("volar")
volar.use_masonlsp_setup = false

M.lspconfigs = { volar }

return M
