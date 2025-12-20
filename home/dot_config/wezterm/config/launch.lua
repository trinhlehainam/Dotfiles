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

-- Shell definitions keyed by name: { exe, label, args }
-- Nushell doesn't use -l; it handles login behavior via config.nu
---@type table<string, {exe: string, label: string, args: string[]}>
local unix_shells = {
  bash = { exe = 'bash', label = 'Bash', args = { 'bash', '-l' } },
  zsh = { exe = 'zsh', label = 'Zsh', args = { 'zsh', '-l' } },
  fish = { exe = 'fish', label = 'Fish', args = { 'fish', '-l' } },
  nu = { exe = 'nu', label = 'Nushell', args = { 'nu' } },
}

---@param launch_menu SpawnCommand[]
---@param shell_order string[]
local function add_unix_shells(launch_menu, shell_order)
  for _, name in ipairs(shell_order) do
    local shell = unix_shells[name]
    if shell then
      add_if_exists(launch_menu, shell.exe, { label = shell.label, args = shell.args })
    end
  end
end

---@param config Config
---@param shell_order string[]
local function set_default_unix_prog(config, shell_order)
  if config.default_prog ~= nil then
    return
  end

  for _, name in ipairs(shell_order) do
    local shell = unix_shells[name]
    if shell and executable.exists(shell.exe) then
      config.default_prog = shell.args
      return
    end
  end
end

local linux_shell_order = { 'bash', 'zsh', 'fish', 'nu' }
local mac_shell_order = { 'zsh', 'bash', 'fish', 'nu' }

---@type {exe: string, label: string, args: string[]}[]
local win_shells = {
  { exe = 'pwsh.exe', label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' } },
  { exe = 'powershell.exe', label = 'PowerShell 5', args = { 'powershell.exe', '-NoLogo' } },
  { exe = 'cmd.exe', label = 'Command Prompt', args = { 'cmd.exe' } },
}

---@param config Config
local function set_default_win_prog(config)
  if config.default_prog ~= nil then
    return
  end

  for _, shell in ipairs(win_shells) do
    if executable.exists(shell.exe) then
      config.default_prog = shell.args
      return
    end
  end
end

---@type ConfigModule
return {
  -- Note: `executable.exists()` uses `wezterm.run_child_process`, which must not be
  -- invoked during module load (`require`). Build `launch_menu` inside this callback.
  -- Ref: https://github.com/wezterm/wezterm/issues/6226
  apply_to_config = function(config)
    ---@type SpawnCommand[]
    local launch_menu = {}

    if platform.is_win then
      for _, shell in ipairs(win_shells) do
        add_if_exists(launch_menu, shell.exe, { label = shell.label, args = shell.args })
      end

      if executable.exists('wsl.exe') then
        for _, domain in ipairs(wsl.domains()) do
          table.insert(launch_menu, {
            label = domain.distribution,
            args = { 'wsl.exe', '-d', domain.distribution },
          })
        end
      end
    elseif platform.is_linux then
      add_unix_shells(launch_menu, linux_shell_order)
    elseif platform.is_mac then
      add_unix_shells(launch_menu, mac_shell_order)
    end

    if #launch_menu > 0 then
      config.launch_menu = launch_menu
    end

    if platform.is_win then
      set_default_win_prog(config)
    elseif platform.is_linux then
      set_default_unix_prog(config, linux_shell_order)
    elseif platform.is_mac then
      set_default_unix_prog(config, mac_shell_order)
    end
  end,
}
