---Small helper to assemble the main WezTerm config.
---
---`wezterm.lua` uses this builder to:
--- - register event handlers (via `:event(...)`)
--- - apply config fragments from `config/*.lua` (via `:load(...)`)
---
---Each method operates on a single config table created by `wezterm.config_builder()`
---and returns the builder itself to support fluent chaining.
---
---A config fragment is just a Lua module that exports `apply_to_config(config)`.
---@see https://wezterm.org/config/files.html#making-your-own-lua-modules

---@class ConfigModule
---@field apply_to_config fun(config: Config)

local wezterm = require('wezterm') ---@type Wezterm

---@class ConfigBuilder
---@field config Config
local ConfigBuilder = {}
ConfigBuilder.__index = ConfigBuilder

---Create a fresh builder with a default/validated config table.
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

---Run a function that registers event handlers (e.g. via `wezterm.on`).
---
---This is kept separate from `:load(...)` so event modules don't need to pretend
---they are config fragments.
---@param setup fun(): nil
---@return ConfigBuilder
function ConfigBuilder:event(setup)
  setup()
  return self
end

return ConfigBuilder
