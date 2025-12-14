local platform = require('utils.platform')
local wsl = require('utils.wsl')

if not platform.is_win then
  return function(_) end
end

local domains = wsl.domains()
local default_domain = wsl.default_domain_name()

--- @param config Config
return function(config)
  config.wsl_domains = domains

  if default_domain then
    config.default_domain = default_domain
  end
end
