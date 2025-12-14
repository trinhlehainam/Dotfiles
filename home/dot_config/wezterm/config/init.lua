local wezterm = require('wezterm') ---@type Wezterm

---@class ConfigBuilder
---@field config Config
local ConfigBuilder = {}
ConfigBuilder.__index = ConfigBuilder

---@param destination Config
---@param source Config
local function merge_config(destination, source)
  for k, v in pairs(source or {}) do
    if destination[k] ~= nil then
      wezterm.log_warn('Duplicate config option detected: ', { old = destination[k], new = v })
      goto continue
    end

    destination[k] = v
    ::continue::
  end
end

---@return ConfigBuilder
function ConfigBuilder:init()
  local builder = setmetatable({ options = {}, _post_apply = {} }, self)
  return builder
end

---@param config Config
---@return ConfigBuilder
function ConfigBuilder:append(config)
  if type(config) == 'table' then
    merge_config(self.config, config)
  end

  return self
end

---Register an event setup function (e.g. wezterm.on(...)).
---@param setup fun()
---@return ConfigBuilder
function ConfigBuilder:event(setup)
  setup()
  return self
end

---@return table
function ConfigBuilder:build()
  local config = wezterm.config_builder()

  for k, v in pairs(self.config) do
    config[k] = v
  end

  return config
end

return ConfigBuilder
