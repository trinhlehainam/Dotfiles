local M = {}
local base = require("lsp.base")
setmetatable(M, base)

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

M.lang_server = "jsonls"
M.lspconfig = function()
  require('lspconfig').jsonls.setup {
    capabilities = capabilities,
    on_attach = require('utils').on_attach,
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
