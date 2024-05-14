---@alias custom.LspConfig.Setup fun(capabilities: lsp.ClientCapabilities, on_attach: fun(client: lsp.Client, bufnr: integer))

---@class custom.LspConfig
---@field setup? custom.LspConfig.Setup
---@field settings table

---@class custom.Lang
---@field lang_server? string
---@field lspconfig custom.LspConfig
---@field dap_type? string
---@field dapconfig? Configuration[]
local M = {}

---@return custom.Lang
function M:new()
  local t = setmetatable({}, { __index = M })
  t.lspconfig = {
    setup = nil,
    settings = {}
  }
  return t
end

return M
