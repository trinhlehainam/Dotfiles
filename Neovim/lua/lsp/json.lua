--- @type Lang
local M = {}
local base = require("lsp.base")
setmetatable(M, base)

M.lang_server = "jsonls"
M.lspconfig = function(capabilities, on_attach)
  require('lspconfig').jsonls.setup {
    capabilities = capabilities,
    on_attach = on_attach,
    settings = {
      json = {
        schemas = require('schemastore').json.schemas(),
        extra = {
          description = 'komorebi JSON Schema',
          fileMatch = 'komorebi.json',
          name = 'komorebi.json',
          url = 'https://github.com/LGUG2Z/komorebi/blob/master/schema.json',
        },
      },
      validate = { enable = true },
    },
  }
end

return M
