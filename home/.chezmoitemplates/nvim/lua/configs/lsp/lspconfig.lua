---@class custom.LspConfig
local M = {}

---@param server string?
---@return custom.LspConfig
function M:new(server)
  local t = setmetatable({}, { __index = M })
  t.server = server
  t.use_masonlsp_setup = true
  t.settings = {}
  t.setup = nil
  return t
end

return M
