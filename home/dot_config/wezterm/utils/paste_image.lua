local wezterm = require('wezterm') ---@type Wezterm

local platform = require('utils.platform')
local strings = require('utils.strings')
local wsl = require('utils.wsl')

local M = {}

---@param window Window
---@param pane Pane
local function fallback_paste(window, pane)
  window:perform_action(wezterm.action.PasteFrom('Clipboard'), pane)
end

---@param value string
---@return string
local function escape_powershell_single_quote(value)
  return value:gsub("'", "''")
end

---@param cwd_uri string
---@return string|nil
local function file_uri_to_linux_path(cwd_uri)
  local path = cwd_uri:match('^file://[^/]*(/.*)$') or cwd_uri:match('^file:(/.*)$')
  if not path then
    return nil
  end

  return strings.percent_decode(path)
end

---@param pane Pane
---@return string|nil
local function linux_cwd_from_pane(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd then
    return nil
  end

  if type(cwd) == 'table' then
    if type(cwd.file_path) == 'string' and cwd.file_path ~= '' then
      return cwd.file_path
    end

    if type(cwd.path) == 'string' and cwd.path ~= '' then
      return cwd.path
    end

    if type(cwd.uri) == 'string' and cwd.uri ~= '' then
      return file_uri_to_linux_path(cwd.uri)
    end
  elseif type(cwd) == 'string' then
    return file_uri_to_linux_path(cwd) or cwd
  end

  return file_uri_to_linux_path(tostring(cwd))
end

---@param pane Pane
---@return string|nil
local function pane_domain_name(pane)
  local ok, domain_name = pcall(function()
    return pane:get_domain_name()
  end)

  if not ok or type(domain_name) ~= 'string' or domain_name == '' then
    return nil
  end

  return domain_name
end

---@param pane Pane
---@return boolean
local function pane_is_wsl(pane)
  local domain_name = pane_domain_name(pane)
  if not domain_name then
    return false
  end

  return domain_name:match('^WSL:') ~= nil
end

---@param wsl_distro string
---@param linux_path string
---@return string|nil
local function wslpath_to_windows(wsl_distro, linux_path)
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

  local windows_path = strings.trim(stdout)
  if windows_path == '' then
    return nil
  end

  return windows_path
end

---@return boolean|nil
local function clipboard_has_image()
  local check_cmd = table.concat({
    'Add-Type -AssemblyName System.Windows.Forms;',
    '[System.Windows.Forms.Clipboard]::ContainsImage()',
  }, ' ')

  local ok, success, stdout, _ = pcall(wezterm.run_child_process, {
    'powershell.exe',
    '-NoProfile',
    '-Command',
    check_cmd,
  })

  if not ok or not success or not stdout then
    return nil
  end

  local state = strings.trim(stdout)
  if state == 'True' then
    return true
  end
  if state == 'False' then
    return false
  end

  return nil
end

---@param windows_path string
---@return boolean
local function save_clipboard_image_png(windows_path)
  local escaped = escape_powershell_single_quote(windows_path)
  local save_cmd = table.concat({
    'Add-Type -AssemblyName System.Windows.Forms;',
    'Add-Type -AssemblyName System.Drawing;',
    '$img = [System.Windows.Forms.Clipboard]::GetImage();',
    'if ($null -eq $img) { exit 1 }',
    string.format("$img.Save('%s', [System.Drawing.Imaging.ImageFormat]::Png)", escaped),
  }, ' ')

  local ok, success = pcall(wezterm.run_child_process, {
    'powershell.exe',
    '-NoProfile',
    '-Command',
    save_cmd,
  })

  return ok and success
end

---@param windows_dir string
---@param filename string
---@return string
local function join_windows_path(windows_dir, filename)
  local sep = windows_dir:match('[\\/]$') and '' or '\\'
  return windows_dir .. sep .. filename
end

---@param window Window
---@param pane Pane
function M.smart_paste(window, pane)
  if not platform.is_win then
    fallback_paste(window, pane)
    return
  end

  if not pane_is_wsl(pane) then
    fallback_paste(window, pane)
    return
  end

  local has_image = clipboard_has_image()
  if has_image ~= true then
    fallback_paste(window, pane)
    return
  end

  local linux_cwd = linux_cwd_from_pane(pane)
  if not linux_cwd then
    fallback_paste(window, pane)
    return
  end

  local wsl_distro = wsl.default_distro()
  if not wsl_distro then
    fallback_paste(window, pane)
    return
  end

  local windows_cwd = wslpath_to_windows(wsl_distro, linux_cwd)
  if not windows_cwd then
    fallback_paste(window, pane)
    return
  end

  local filename = string.format('screenshot_%s.png', wezterm.strftime('%Y%m%d_%H%M%S'))
  local full_windows_path = join_windows_path(windows_cwd, filename)

  if save_clipboard_image_png(full_windows_path) then
    pane:send_text(filename)
    return
  end

  fallback_paste(window, pane)
end

return M
