local Lang = require("configs.lsp.base")
local M = Lang:new()

M.server_name = "jsonls"
M.lspconfig.settings = {
  json = {
    schemas = require('schemastore').json.schemas {
      extra = {
        {
          description = 'Komorebi JSON schema',
          fileMatch = { 'komorebi.json' },
          name = 'komorebi.json',
          url = 'https://raw.githubusercontent.com/LGUG2Z/komorebi/master/schema.json',
        },
      },
    },
    validate = { enable = true },
  },
}

return M
