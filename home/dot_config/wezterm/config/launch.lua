local executable = require('utils.executable')
local platform = require('utils.platform')
local wsl = require('utils.wsl')

---@param launch_menu SpawnCommand[]
---@param exe string
---@param item SpawnCommand
local function add_if_exists(launch_menu, exe, item)
  if executable.exists(exe) then
    table.insert(launch_menu, item)
  end
end

--- @type SpawnCommand[]
local launch_menu = {}

if platform.is_win then
  add_if_exists(launch_menu, 'pwsh.exe', {
    label = 'PowerShell 7',
    args = { 'pwsh.exe', '-NoLogo' },
  })

  add_if_exists(launch_menu, 'powershell.exe', {
    label = 'PowerShell 5',
    args = { 'powershell.exe', '-NoLogo' },
  })

  add_if_exists(launch_menu, 'cmd.exe', {
    label = 'Command Prompt',
    args = { 'cmd.exe' },
  })

  for _, domain in ipairs(wsl.domains()) do
    table.insert(launch_menu, {
      label = domain.name,
      args = { 'wsl.exe', '-d', domain.name },
    })
  end
elseif platform.is_linux then
  add_if_exists(launch_menu, 'bash', {
    label = 'Bash',
    args = { 'bash', '-l' },
  })

  add_if_exists(launch_menu, 'zsh', {
    label = 'Zsh',
    args = { 'zsh', '-l' },
  })

  add_if_exists(launch_menu, 'fish', {
    label = 'Fish',
    args = { 'fish', '-l' },
  })

  add_if_exists(launch_menu, 'nu', {
    label = 'Nushell',
    args = { 'nu' },
  })
elseif platform.is_mac then
  add_if_exists(launch_menu, 'zsh', {
    label = 'Zsh',
    args = { 'zsh', '-l' },
  })

  add_if_exists(launch_menu, 'bash', {
    label = 'Bash',
    args = { 'bash', '-l' },
  })

  add_if_exists(launch_menu, 'fish', {
    label = 'Fish',
    args = { 'fish', '-l' },
  })

  add_if_exists(launch_menu, 'nu', {
    label = 'Nushell',
    args = { 'nu' },
  })
end

--- @type ConfigModule
return {
  apply_to_config = function(config)
    if #launch_menu > 0 then
      config.launch_menu = launch_menu
    end
  end,
}
