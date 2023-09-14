local M = {
  lang_server = function()
    error("Not implemented. Must be a string")
  end,
  -- A function that has two arguments: capabilities and on_attach
  -- function(capabilities, on_attach)
  lspconfig = nil,
  dap_type = nil,
  dapconfig = nil,
}

return M
