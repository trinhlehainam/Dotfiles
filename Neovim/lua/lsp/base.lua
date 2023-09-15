--- @alias on_attach fun(capabilities: lsp.ClientCapabilities, on_attach: fun(client: lsp.Client, bufnr: integer))

--- @class lang
--- @field lang_server nil | string
--- @field lspconfig nil | on_attach
--- @field dap_type nil | string
--- @field dapconfig nil | Configuration

--- @type lang
local M = {
  lang_server = nil,
  lspconfig = nil,
  dap_type = nil,
  dapconfig = nil,
}

return M
