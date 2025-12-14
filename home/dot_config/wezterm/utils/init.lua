local wezterm = require('wezterm') ---@type Wezterm

---@class CustomBuilder
---@field config Config
local Builder = {}
Builder.__index = Builder

---Initialize Config
---@return CustomBuilder
function Builder:init()
  local config = setmetatable({ options = {} }, self)
  return config
end

---Append to `CustomBuilder.configs`
---@param config Config
---@return CustomBuilder
function Builder:append(config)
  for k, v in pairs(config) do
    if self.config[k] ~= nil then
      wezterm.log_warn(
        'Duplicate config option detected: ',
        { old = self.config[k], new = config[k] }
      )
      goto continue
    end
    self.config[k] = v
    ::continue::
  end
  return self
end

return Builder
