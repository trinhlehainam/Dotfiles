local wezterm = require('wezterm')

local platform = require('utils.platform')
local strings = require('utils.strings')
local wsl = require('utils.wsl')

local function wslpath_to_windows(wsl_distro, linux_path)
  if not wsl_distro then
    return nil
  end

  local ok, success, stdout, _ = pcall(wezterm.run_child_process, {
    'wsl.exe',
    '-d',
    wsl_distro,
    '--',
    'wslpath',
    '-w',
    linux_path,
  })

  if not ok or not success or not stdout then
    return nil
  end

  local translated = strings.trim(stdout)
  if translated == '' then
    return nil
  end

  return translated
end

return function()
  wezterm.on('open-uri', function(_, _, uri)
    if not platform.is_win then
      return
    end

    local wsl_distro = wsl.default_distro()

    local windows_path
    if uri:match('^[a-zA-Z]:[\\/].+') then
      windows_path = uri
    elseif uri:match('^/mnt/[a-zA-Z]/') then
      windows_path = wslpath_to_windows(wsl_distro, uri)
    elseif uri:match('^file://') then
      local path = strings.percent_decode(uri:gsub('^file://', ''))
      if path:match('^/mnt/[a-zA-Z]/') then
        windows_path = wslpath_to_windows(wsl_distro, path)
      elseif path:match('^[a-zA-Z]:[\\/].+') then
        windows_path = path
      end
    end

    if windows_path and windows_path ~= '' then
      wezterm.open_with(windows_path)
      return false
    end
  end)
end
