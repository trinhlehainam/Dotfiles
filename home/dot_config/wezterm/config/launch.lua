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
  powershell = {
    exe = 'powershell.exe',
    label = 'PowerShell 5',
    args = { 'powershell.exe', '-NoLogo' },
  },
  cmd = { exe = 'cmd.exe', label = 'Command Prompt', args = { 'cmd.exe' } },
}

-- Shells per platform in preference order
local shells = {
  linux = { unix.bash, unix.zsh, unix.fish, unix.nu },
  mac = { unix.zsh, unix.bash, unix.fish, unix.nu },
  windows = { win.pwsh, win.powershell, win.cmd },
}

-- Adds `launch_menu` entries, and sets `default_prog` (if unset).
--- @param config Config
--- @param launch_menu SpawnCommand[]
local function add_shells(config, launch_menu)
  local platform_shells = shells[platform.os] or {}
  if platform.is_win then
    config.default_prog = nil
  end

  for _, shell in ipairs(platform_shells) do
    if executable.exists(shell.exe) then
      table.insert(launch_menu, { label = shell.label, args = shell.args })

      if config.default_prog == nil then
        config.default_prog = shell.args
      end
    end
  end
end

local function add_wsl_distributions(launch_menu)
  if not executable.exists('wsl.exe') then
    return
  end

  for _, domain in ipairs(wsl.domains()) do
    local distro = (domain.distribution or domain.name)
    if distro then
      distro = distro:gsub('^WSL:', '')
      table.insert(launch_menu, {
        label = distro,
        args = { 'wsl.exe', '-d', distro },
      })
    end
  end
end

--- @type ConfigModule
return {
  -- Note: `executable.exists()` uses `wezterm.run_child_process`, which must not be
  -- invoked during module load (`require`). Only call it from this callback.
  -- Ref: https://github.com/wezterm/wezterm/issues/6226
  apply_to_config = function(config)
    --- @type SpawnCommand[]
    local launch_menu = {}

    add_shells(config, launch_menu)

    if platform.is_win then
      add_wsl_distributions(launch_menu)
    end

    if #launch_menu > 0 then
      config.launch_menu = launch_menu
    end
  end,
}
