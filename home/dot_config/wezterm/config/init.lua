local wezterm = require('wezterm')

---@class Config
local Config = {}
Config.__index = Config

---Initialize Config
---@return Config
function Config:init()
   local config = setmetatable(wezterm.config_builder(), Config)
   return config
end

---Append to `Config.options`
---@param new_options table new options to append
---@return Config
function Config:append(new_options)
   for k, v in pairs(new_options) do
      if v == nil then
         goto continue
      end
      self[k] = v
      ::continue::
   end
   return self
end

return Config
