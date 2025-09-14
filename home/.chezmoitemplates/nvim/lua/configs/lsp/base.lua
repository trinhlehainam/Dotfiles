---@class custom.LanguageSetting
local M = {}

---@return custom.LanguageSetting
function M:new()
  local t = setmetatable({}, { __index = M })
  t.treesitter = {
    filetypes = nil,
  }
  t.lspconfig = {
    server = nil,
    mason_package = nil,
    config = {},
  }
  t.lspconfigs = {}
  t.dapconfigs = {}
  t.formatterconfig = {
    servers = nil,
    formatters_by_ft = nil,
  }
  t.linterconfig = {
    servers = nil,
    linters_by_ft = nil,
  }
  return t
end

return M
