local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.server_name = "yamlls"
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
