local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'markdown', 'markdown_inline' }

local capabilities = {
  workspace = {
    didChangeWatchedFiles = {
      dynamicRegistration = true,
    },
  },
}

local ok, blink = pcall(require, 'blink.cmp')
if ok then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

local markdown_oxide = LspConfig:new('markdown_oxide', 'markdown-oxide')
markdown_oxide.config = {
  capabilities = capabilities,
}

M.lspconfigs = { markdown_oxide }

return M