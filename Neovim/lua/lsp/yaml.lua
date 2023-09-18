local Lang = require("lsp.base")
local M = Lang:new()

M.lang_server = "yamlls"
M.lspconfig.settings = {
  yaml = {
    schemaStore = {
      -- You must disable built-in schemaStore support if you want to use
      -- this plugin and its advanced options like `ignore`.
      enable = false,
      -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
      url = "",
    },
    schemas = require('schemastore').yaml.schemas(),
  },
}

return M
