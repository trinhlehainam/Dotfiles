local M = {}
local base = require("lsp.base")
setmetatable(M, base)

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()

capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
M.lang_server = "yamlls"
M.lspconfig = function()
  require('lspconfig').yamlls.setup {
    capabilities = capabilities,
    on_attach = require('utils').on_attach,
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
