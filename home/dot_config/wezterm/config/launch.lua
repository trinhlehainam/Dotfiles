local executable = require('utils.executable')
local platform = require('utils.platform')
local wsl = require('utils.wsl')

if not platform.is_win then
  --- @type ConfigModule
  return {
    apply_to_config = function(_) end,
  }
end

local launch_menu = {}

if executable.exists('pwsh.exe') then
  table.insert(launch_menu, {
    label = 'PowerShell 7',
    domain = { DomainName = 'local' },
    args = { 'pwsh.exe', '-NoLogo' },
  })
end

if executable.exists('powershell.exe') then
  table.insert(launch_menu, {
    label = 'PowerShell 5',
    domain = { DomainName = 'local' },
    args = { 'powershell.exe', '-NoLogo' },
  })
end

if executable.exists('cmd.exe') then
  table.insert(launch_menu, {
    label = 'Command Prompt',
    domain = { DomainName = 'local' },
    args = { 'cmd.exe' },
  })
end

for _, domain in ipairs(wsl.domains()) do
  table.insert(launch_menu, {
    label = domain.name,
    domain = { DomainName = domain.name },
  })
end

--- @type ConfigModule
return {
  apply_to_config = function(config)
    config.launch_menu = launch_menu
  end,
}
