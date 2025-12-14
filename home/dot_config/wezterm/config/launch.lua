local platform = require('utils.platform')
local wsl = require('utils.wsl')

local launch_menu = {
  { label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' } },
  { label = 'PowerShell 5', args = { 'powershell.exe', '-NoLogo' } },
  { label = 'Command Prompt', args = { 'cmd.exe' } },
}

if platform.is_win then
  for _, domain in ipairs(wsl.domains()) do
    table.insert(launch_menu, {
      label = domain.name,
      domain = { DomainName = domain.name },
    })
  end
end

return {
  launch_menu = launch_menu,
}
