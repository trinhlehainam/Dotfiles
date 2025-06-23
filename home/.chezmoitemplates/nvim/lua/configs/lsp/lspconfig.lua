---@class custom.LspConfig
local M = {}

---@param server string?
---@param mason_package string?
---@return custom.LspConfig
function M:new(server, mason_package)
  local t = setmetatable({}, { __index = M })
  t.server = server
  t.mason_package = mason_package
  t.config = {}
  t.setup = nil
  return t
end

return M
