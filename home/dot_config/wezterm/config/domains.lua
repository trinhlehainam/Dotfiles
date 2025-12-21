local platform = require('utils.platform')
local wsl = require('utils.wsl')

if not platform.is_win then
  --- @type ConfigModule
  return {
    apply_to_config = function(_) end,
  }
end

-- Preferred WSL distro (e.g., 'Ubuntu', 'Debian').
-- Set to nil to use the first detected WSL domain.
wsl.set_preferred('Ubuntu')

---@type ConfigModule
return {
  apply_to_config = function(config)
    config.wsl_domains = wsl.domains()

    local default_domain = wsl.default_domain_name()
    if default_domain then
      config.default_domain = default_domain
    end
  end,
}
