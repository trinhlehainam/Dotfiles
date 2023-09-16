--- @type Lang
local M = {}
local base = require("lsp.base")
setmetatable(M, base)

M.lang_server = "yamlls"
M.lspconfig = function(capabilities, on_attach)
  require('lspconfig').yamlls.setup {
    capabilities = capabilities,
    on_attach = on_attach,
    settings = {
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
    },
  }
end

return M
