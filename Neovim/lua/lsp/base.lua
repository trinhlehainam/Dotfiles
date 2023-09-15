local M = {
  --- @type nil | string
  lang_server = nil,
  --- A function that has two arguments: capabilities and on_attach
  --- @type nil | fun(capabilities: table, on_attach: fun(client: lsp.Client, bufnr: integer))
  lspconfig = nil,
  --- @type nil | string
  dap_type = nil,
  --- @type nil | table
  dapconfig = nil,
}

return M
