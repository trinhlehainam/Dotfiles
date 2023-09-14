local M = {
  lang_server = function()
    error("Not implemented. Must be a string")
  end,
  -- Use Mason lspconfig if this is not set (nil)
  lspconfig = nil,
  dap_type = function()
    error("Not implemented. Must be a string")
  end,
  dapconfig = function()
    error("Not implemented. Must be a table")
  end,
}

return M
