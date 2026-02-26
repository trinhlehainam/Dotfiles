local wezterm = require('wezterm') ---@type Wezterm

local platform = require('utils.platform')
local strings = require('utils.strings')

local M = {}

local WSL_TEMP_DIR = '/tmp/wezterm-smart-paste'

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

---@param linux_dir string
---@param filename string
---@return string
local function join_linux_path(linux_dir, filename)
  local sep = linux_dir:match('/$') and '' or '/'
  return linux_dir .. sep .. filename
end

---@param wsl_distro string
---@param linux_dir string
---@return boolean
local function ensure_wsl_dir(wsl_distro, linux_dir)
  local ok, success = pcall(wezterm.run_child_process, {
    'wsl.exe',
    '-d',
    wsl_distro,
    '--',
    'mkdir',
    '-p',
    linux_dir,
  })

  return ok and success
end

---@param pane Pane
---@return string|nil
local function pane_wsl_distro(pane)
  local domain_name = pane_domain_name(pane)
  if not domain_name then
    return nil
  end

  local distro = domain_name:match('^WSL:(.+)$')
  if not distro then
    return nil
  end

  distro = strings.trim(distro)
  if distro == '' then
    return nil
  end

  return distro
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

---@param pane Pane
---@return boolean
local function try_smart_paste(pane)
  if not platform.is_win then
    return false
  end

  local wsl_distro = pane_wsl_distro(pane)
  if not wsl_distro then
    return false
  end

  local has_image = clipboard_has_image()
  if has_image ~= true then
    return false
  end

  if not ensure_wsl_dir(wsl_distro, WSL_TEMP_DIR) then
    return false
  end

  local windows_temp_dir = wslpath_to_windows(wsl_distro, WSL_TEMP_DIR)
  if not windows_temp_dir then
    return false
  end

  local filename = string.format('screenshot_%s.png', wezterm.strftime('%Y%m%d_%H%M%S'))
  local full_windows_path = join_windows_path(windows_temp_dir, filename)
  local full_linux_path = join_linux_path(WSL_TEMP_DIR, filename)

  if not save_clipboard_image_png(full_windows_path) then
    return false
  end

  pane:send_text('@' .. full_linux_path)
  return true
end

---@param window Window
---@param pane Pane
function M.smart_paste(window, pane)
  if try_smart_paste(pane) then
    return
  end

  fallback_paste(window, pane)
end

return M
