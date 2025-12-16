local wezterm = require('wezterm') ---@type Wezterm

---@class ConfigModule
---@see https://wezterm.org/config/files.html#making-your-own-lua-modules
---@field apply_to_config fun(config: Config)

---@class ConfigBuilder
---@field config Config
local ConfigBuilder = {}
ConfigBuilder.__index = ConfigBuilder

---@return ConfigBuilder
function ConfigBuilder:init()
  local builder = setmetatable({ config = wezterm.config_builder() }, self)
  return builder
end

---@param module ConfigModule
---@return ConfigBuilder
function ConfigBuilder:load(module)
  module.apply_to_config(self.config)
  return self
end

---Register an event setup function (e.g. wezterm.on(...)).
---@param setup fun()
---@return ConfigBuilder
function ConfigBuilder:event(setup)
  setup()
  return self
end

return ConfigBuilder
