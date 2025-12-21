local executable = require('utils.executable')
local platform = require('utils.platform')
local wsl = require('utils.wsl')

-- Unix shells (shared between Linux and macOS)
-- Note: Nushell doesn't use -l; it handles login behavior via config.nu
local unix = {
  bash = { exe = 'bash', label = 'Bash', args = { 'bash', '-l' } },
  zsh = { exe = 'zsh', label = 'Zsh', args = { 'zsh', '-l' } },
  fish = { exe = 'fish', label = 'Fish', args = { 'fish', '-l' } },
  nu = { exe = 'nu', label = 'Nushell', args = { 'nu' } },
}

-- Windows shells
local win = {
  pwsh = { exe = 'pwsh.exe', label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' } },
  powershell = { exe = 'powershell.exe', label = 'PowerShell 5', args = { 'powershell.exe', '-NoLogo' } },
  cmd = { exe = 'cmd.exe', label = 'Command Prompt', args = { 'cmd.exe' } },
}

-- Shells per platform in preference order
local shells = {
  linux = { unix.bash, unix.zsh, unix.fish, unix.nu },
  mac = { unix.zsh, unix.bash, unix.fish, unix.nu },
  windows = { win.pwsh, win.powershell, win.cmd },
}

local function add_shells(launch_menu)
  for _, shell in ipairs(shells[platform.os] or {}) do
    if executable.exists(shell.exe) then
      table.insert(launch_menu, { label = shell.label, args = shell.args })
    end
  end
end

local function set_default_prog(config)
  if config.default_prog then
    return
  end
  for _, shell in ipairs(shells[platform.os] or {}) do
    if executable.exists(shell.exe) then
      config.default_prog = shell.args
      return
    end
  end
end

local function add_wsl_distributions(launch_menu)
  if not executable.exists('wsl.exe') then
    return
  end
  for _, domain in ipairs(wsl.domains()) do
    table.insert(launch_menu, {
      label = domain.distribution,
      args = { 'wsl.exe', '-d', domain.distribution },
    })
  end
end

return {
  apply_to_config = function(config)
    local launch_menu = {}

    add_shells(launch_menu)

    if platform.is_win then
      add_wsl_distributions(launch_menu)
    end

    if #launch_menu > 0 then
      config.launch_menu = launch_menu
    end

    set_default_prog(config)
  end,
}
