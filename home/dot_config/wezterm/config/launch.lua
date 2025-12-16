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

-- Shell definitions: { exe, label, args }
-- Nushell doesn't use -l; it handles login behavior via config.nu
---@type table<string, {label: string, args: string[]}>
local unix_shells = {
  bash = { label = 'Bash', args = { 'bash', '-l' } },
  zsh = { label = 'Zsh', args = { 'zsh', '-l' } },
  fish = { label = 'Fish', args = { 'fish', '-l' } },
  nu = { label = 'Nushell', args = { 'nu' } },
}

---@param launch_menu SpawnCommand[]
---@param shell_order string[]
local function add_unix_shells(launch_menu, shell_order)
  for _, name in ipairs(shell_order) do
    local shell = unix_shells[name]
    if shell then
      add_if_exists(launch_menu, name, { label = shell.label, args = shell.args })
    end
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
      label = domain.distribution,
      args = { 'wsl.exe', '-d', domain.distribution },
    })
  end
elseif platform.is_linux then
  add_unix_shells(launch_menu, { 'bash', 'zsh', 'fish', 'nu' })
elseif platform.is_mac then
  add_unix_shells(launch_menu, { 'zsh', 'bash', 'fish', 'nu' })
end

--- @type ConfigModule
return {
  apply_to_config = function(config)
    if #launch_menu > 0 then
      config.launch_menu = launch_menu
    end
  end,
}
