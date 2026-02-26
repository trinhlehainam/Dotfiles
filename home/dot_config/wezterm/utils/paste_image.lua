local wezterm = require('wezterm') ---@type Wezterm

local platform = require('utils.platform')
local strings = require('utils.strings')
local wsl = require('utils.wsl')

local M = {}

local WSL_TEMP_DIR = '/tmp/wezterm-smart-paste'
---@enum SaveStatus
local SAVE_STATUS = {
  SAVED = 'SAVED',
  NO_IMAGE = 'NO_IMAGE',
  SAVE_FAILED = 'SAVE_FAILED',
}

---@type table<string, SaveStatus>
local SAVE_STATUS_BY_VALUE = {}
for _, enum_value in pairs(SAVE_STATUS) do
  SAVE_STATUS_BY_VALUE[enum_value] = enum_value
end

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

---@param linux_dir string
---@param filename string
---@return string
local function join_linux_path(linux_dir, filename)
  local sep = linux_dir:match('/$') and '' or '/'
  return linux_dir .. sep .. filename
end

---@param value string
---@return SaveStatus|nil
local function enum_save_status(value)
  return SAVE_STATUS_BY_VALUE[value]
end

---@return string
local function make_screenshot_filename()
  if wezterm.time and wezterm.time.now then
    local timestamp = wezterm.time.now():format('%Y%m%d_%H%M%S_%3f')
    return string.format('screenshot_%s.png', timestamp)
  end

  -- Fallback for older runtimes: keep second precision but add random suffix.
  return string.format('screenshot_%s_%06d.png', wezterm.strftime('%Y%m%d_%H%M%S'), math.random(0, 999999))
end

---@param windows_path string
---@return SaveStatus|nil
local function save_clipboard_image_png(windows_path)
  local escaped = escape_powershell_single_quote(windows_path)
  local save_cmd = table.concat({
    "$ErrorActionPreference = 'Stop';",
    'Add-Type -AssemblyName System.Windows.Forms;',
    'Add-Type -AssemblyName System.Drawing;',
    '$img = [System.Windows.Forms.Clipboard]::GetImage();',
    string.format("if ($null -eq $img) { Write-Output '%s'; exit 0 }", SAVE_STATUS.NO_IMAGE),
    'try {',
    string.format("$img.Save('%s', [System.Drawing.Imaging.ImageFormat]::Png);", escaped),
    string.format("Write-Output '%s';", SAVE_STATUS.SAVED),
    '} catch {',
    string.format("Write-Output '%s';", SAVE_STATUS.SAVE_FAILED),
    '}',
  }, ' ')

  local ok, success, stdout, _ = pcall(wezterm.run_child_process, {
    'powershell.exe',
    '-NoProfile',
    '-Command',
    save_cmd,
  })

  if not ok or not success or not stdout then
    return nil
  end

  return enum_save_status(strings.trim(stdout))
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

  local wsl_distro = wsl.pane_distro(pane)
  if not wsl_distro then
    return false
  end

  if not wsl.ensure_dir(wsl_distro, WSL_TEMP_DIR) then
    return false
  end

  local windows_temp_dir = wsl.path_to_windows_cached(wsl_distro, WSL_TEMP_DIR)
  if not windows_temp_dir then
    return false
  end

  local filename = make_screenshot_filename()
  local full_windows_path = join_windows_path(windows_temp_dir, filename)
  local full_linux_path = join_linux_path(WSL_TEMP_DIR, filename)

  local save_state = save_clipboard_image_png(full_windows_path)
  if save_state ~= SAVE_STATUS.SAVED then
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
