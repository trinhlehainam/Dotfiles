local wezterm = require('wezterm') ---@type Wezterm
local act = wezterm.action ---@type Action

-- Plugin: smart-splits integration
-- https://github.com/mrjones2014/smart-splits.nvim?tab=readme-ov-file#wezterm
local smart_splits = wezterm.plugin.require('https://github.com/mrjones2014/smart-splits.nvim')

local config = wezterm.config_builder() ---@type Config

local is_windows = wezterm.target_triple:find('windows') ~= nil
local is_linux = wezterm.target_triple:find('linux') ~= nil

local function trim(value)
  return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function percent_decode(value)
  return (value:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function extend_list(destination, source)
  for _, value in ipairs(source) do
    table.insert(destination, value)
  end
end

-- =============================================================================
-- GPU & Performance
-- =============================================================================
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'
config.max_fps = 120
config.animation_fps = 60
config.scrollback_lines = 10000

-- =============================================================================
-- Windows Visual Effects
-- =============================================================================
if is_windows then
  config.win32_system_backdrop = 'Disable' -- 'Acrylic', 'Tabbed', or 'Disable'
  config.window_background_opacity = 0.6 -- Mica/Tabbed require 0
  config.window_decorations = 'INTEGRATED_BUTTONS | RESIZE'
  config.integrated_title_button_style = 'Windows'
end

-- =============================================================================
-- WSL Domains
-- =============================================================================
local default_wsl_domain
if is_windows then
  config.wsl_domains = wezterm.default_wsl_domains()

  for _, domain in ipairs(config.wsl_domains) do
    if domain.name == 'WSL:Ubuntu' then
      default_wsl_domain = domain.name
      break
    end
  end

  if not default_wsl_domain and #config.wsl_domains > 0 then
    default_wsl_domain = config.wsl_domains[1].name
  end

  if default_wsl_domain then
    config.default_domain = default_wsl_domain
  end
end

-- =============================================================================
-- Launch Menu
-- =============================================================================
config.launch_menu = {
  { label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' } },
  { label = 'PowerShell 5', args = { 'powershell.exe', '-NoLogo' } },
  { label = 'Command Prompt', args = { 'cmd.exe' } },
}

if is_windows and config.wsl_domains then
  for _, domain in ipairs(config.wsl_domains) do
    table.insert(config.launch_menu, {
      label = domain.name,
      domain = { DomainName = domain.name },
    })
  end
end

-- =============================================================================
-- Environment Variables
-- =============================================================================
config.set_environment_variables = {
  TERM_PROGRAM = 'WezTerm',
  COLORTERM = 'truecolor',
}

-- =============================================================================
-- Fonts
-- =============================================================================
config.font = wezterm.font_with_fallback({
  { family = 'JetBrainsMono Nerd Font', weight = 'Thin' },
})
config.font_size = 12.0
config.line_height = 1
config.cell_width = 1
config.use_cap_height_to_scale_fallback_fonts = true
config.allow_square_glyphs_to_overflow_width = 'WhenFollowedBySpace'

-- Font rendering (ClearType-like for Windows)
config.freetype_load_target = 'Light'
config.freetype_render_target = 'HorizontalLcd'

-- =============================================================================
-- Tab Bar
-- =============================================================================
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 25

-- =============================================================================
-- Window
-- =============================================================================
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}
config.initial_cols = 120
config.initial_rows = 30

-- =============================================================================
-- URI Handler (WSL path translation)
-- =============================================================================
wezterm.on('open-uri', function(_, _, uri)
  if not is_windows then
    return
  end

  local wsl_distro
  if default_wsl_domain then
    wsl_distro = default_wsl_domain:gsub('^WSL:', '')
  end

  local function wslpath_to_windows(linux_path)
    if not wsl_distro then
      return
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
      return
    end

    local translated = trim(stdout)
    if translated == '' then
      return
    end

    return translated
  end

  local windows_path

  if uri:match('^[a-zA-Z]:[\\/].+') then
    windows_path = uri
  elseif uri:match('^/mnt/[a-zA-Z]/') then
    windows_path = wslpath_to_windows(uri)
  elseif uri:match('^file://') then
    local path = percent_decode(uri:gsub('^file://', ''))
    if path:match('^/mnt/[a-zA-Z]/') then
      windows_path = wslpath_to_windows(path)
    elseif path:match('^[a-zA-Z]:[\\/].+') then
      windows_path = path
    end
  end

  if windows_path and windows_path ~= '' then
    wezterm.open_with(windows_path)
    return false
  end
end)

-- =============================================================================
-- Panes: smart-splits integration
-- =============================================================================
smart_splits.apply_to_config(config, {
  direction_keys = {
    move = { 'h', 'j', 'k', 'l' },
    resize = { ',', 'd', 'u', '.' },
  },
  modifiers = {
    move = 'CTRL',
    resize = 'META',
  },
  log_level = 'info',
})

-- =============================================================================
-- Leader Key
-- =============================================================================
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

-- =============================================================================
-- Keybindings
-- =============================================================================
config.keys = config.keys or {}

local copy_destination = is_linux and 'ClipboardAndPrimarySelection' or 'Clipboard'
extend_list(config.keys, {
  -- Clipboard
  { key = 'C', mods = 'CTRL|SHIFT', action = act.CopyTo(copy_destination) },
  { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom('Clipboard') },

  -- Launch menu (ALT+L to open)
  {
    key = 'l',
    mods = 'ALT',
    action = act.ShowLauncherArgs({ flags = 'FUZZY|LAUNCH_MENU_ITEMS|DOMAINS|WORKSPACES' }),
  },

  -- Tab switcher
  { key = 't', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },

  -- Pane splitting (Leader + - or |)
  { key = '-', mods = 'LEADER', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
  { key = '|', mods = 'LEADER', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane({ confirm = true }) },

  -- Tab management
  { key = 'c', mods = 'LEADER', action = act.SpawnTab('CurrentPaneDomain') },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },

  -- Copy mode
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },

  -- Workspaces
  { key = 's', mods = 'LEADER', action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }) },
})

return config
