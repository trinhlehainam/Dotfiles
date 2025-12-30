---WezTerm config builder.
---
---`wezterm.lua` uses this to:
--- - load config modules with `:load(module)`
--- - register events with `:event(fn)`
---
---Config modules must export `apply_to_config(config)`.
---@class ConfigBuilder
---@field config Config
---@source https://wezterm.org/config/files.html#making-your-own-lua-modules
local ConfigBuilder = {}
ConfigBuilder.__index = ConfigBuilder

---@class ConfigModule
---@field apply_to_config fun(config: Config)

local wezterm = require('wezterm') ---@type Wezterm

---Finalize and return the assembled config.
---@return Config
function ConfigBuilder:build()
  return self.config
end

---Create a fresh builder.
---@return ConfigBuilder
function ConfigBuilder:init()
  local builder = setmetatable({ config = wezterm.config_builder() }, self)
  return builder
end

---Apply a config fragment module to the builder's config table.
---@param module ConfigModule
---@return ConfigBuilder
function ConfigBuilder:load(module)
  module.apply_to_config(self.config)
  return self
end

---Run an event setup function (usually calls `wezterm.on`).
---@param setup fun(): nil
---@return ConfigBuilder
function ConfigBuilder:event(setup)
  setup()
  return self
end

return ConfigBuilder
