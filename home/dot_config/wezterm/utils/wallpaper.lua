---Wallpaper picker for WezTerm.
---
---Images live in `assets/wallpapers/` (relative to `wezterm.config_dir()`).
---
---When enabled, applies window overrides:
--- - `background` with image layer + adaptive color overlay
---   Overlay uses your active `color_scheme` background
---
---A keybinding is configured in `config/wallpaper.lua` (default: `CTRL+SHIFT+B`).
---
---@module utils.wallpaper
---@source https://wezterm.org/config/lua/config/background.html
---@source https://wezterm.org/config/lua/keyassignment/InputSelector.html
---@source https://wezterm.org/config/lua/keyassignment/PromptInputLine.html
---@source https://github.com/KevinSilvester/wezterm-config/blob/master/utils/backdrops.lua

local wezterm = require('wezterm') ---@type Wezterm
local act = wezterm.action

---Module API.
---@class WallpaperModule
---@field show_picker fun(window: Window, pane: Pane) Opens the wallpaper menu
local M = {}

-------------------------------------------------------------------------------
-- Types
-------------------------------------------------------------------------------

---Wallpaper state stored in `wezterm.GLOBAL.wallpaper`.
---@class WallpaperState
---@field image string Current wallpaper path; empty string means disabled
---@field brightness number Brightness multiplier (0.0-1.0)
---@field overlay_opacity number Opacity of the color overlay (0.0-1.0)
---@field base_window_background_opacity number|nil Cached baseline window opacity

---Options for numeric input prompt.
---@class NumericInputOpts
---@field title string Prompt title
---@field state_key string State key to update
---@field min number Minimum percentage value
---@field max number Maximum percentage value

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

---Supported image extensions per WezTerm docs (case-insensitive).
---@source https://wezterm.org/config/lua/config/background.html#source-definition
---Supports: PNG, JPEG, GIF, BMP, ICO, TIFF, PNM, DDS, TGA, farbfeld
local IMAGE_EXTENSIONS = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  bmp = true,
  ico = true,
  tiff = true,
  tif = true,
  pnm = true,
  pbm = true,
  pgm = true,
  ppm = true,
  dds = true,
  tga = true,
  ff = true, -- farbfeld
}

-------------------------------------------------------------------------------
-- State Management
-------------------------------------------------------------------------------

---Default wallpaper state values.
---@type WallpaperState
local DEFAULT_STATE = {
  image = '',
  brightness = 0.3,
  overlay_opacity = 0.9,
  base_window_background_opacity = nil,
}

---Get or initialize wallpaper state from GLOBAL.
---@return WallpaperState
local function get_state()
  if not wezterm.GLOBAL.wallpaper then
    wezterm.GLOBAL.wallpaper = {
      image = DEFAULT_STATE.image,
      brightness = DEFAULT_STATE.brightness,
      overlay_opacity = DEFAULT_STATE.overlay_opacity,
      base_window_background_opacity = DEFAULT_STATE.base_window_background_opacity,
    }
  end
  return wezterm.GLOBAL.wallpaper
end

---Partial state update for WallpaperState.
---@class WallpaperStatePatch
---@field image? string
---@field brightness? number
---@field overlay_opacity? number
---@field base_window_background_opacity? number|nil

---Merge a partial state update into `wezterm.GLOBAL.wallpaper`.
---@param partial WallpaperStatePatch
local function set_state(partial)
  local state = get_state()
  for k, v in pairs(partial) do
    state[k] = v
  end
  wezterm.GLOBAL.wallpaper = state
end

-------------------------------------------------------------------------------
-- Image Helpers
-------------------------------------------------------------------------------

---Get the wallpapers directory path.
---
---Directory is expected at: `${wezterm.config_dir}/assets/wallpapers`.
---
---Note: depending on wezterm version, `wezterm.config_dir` may be either a
---string or a function; this helper supports both.
---@return string
local function get_wallpapers_dir()
  local config_dir = wezterm.config_dir
  if type(config_dir) == 'function' then
    config_dir = config_dir()
  end

  local sep = package.config:sub(1, 1)
  return table.concat({ config_dir, 'assets', 'wallpapers' }, sep)
end

---Check if a path has a supported image extension.
---@param path string
---@return boolean
local function is_image(path)
  local ext = path:match('%.([^%.]+)$')
  if not ext then
    return false
  end
  ext = ext:lower()
  return IMAGE_EXTENSIONS[ext] == true
end

---Get sorted list of image paths from the wallpapers directory.
---
---This is a non-recursive scan of `assets/wallpapers/*`.
---Results are sorted for deterministic next/previous ordering.
---@return string[]
local function get_images()
  local dir = get_wallpapers_dir()
  local sep = package.config:sub(1, 1)
  local pattern = dir .. sep .. '*'
  local files = wezterm.glob(pattern)

  local images = {}
  for _, path in ipairs(files) do
    if is_image(path) then
      table.insert(images, path)
    end
  end

  table.sort(images)
  return images
end

---Extract filename from a full path.
---@param path string
---@return string
local function basename(path)
  return path:match('[^/\\]+$') or path
end

-------------------------------------------------------------------------------
-- Background Layer
-------------------------------------------------------------------------------

---Build a background layer table for the given image.
---@param path string
---@param brightness number
---@return BackgroundLayer
local function make_image_layer(path, brightness)
  ---@type BackgroundLayer
  return {
    source = { File = path },
    opacity = 1.0,
    hsb = { hue = 1.0, saturation = 1.0, brightness = brightness },
    width = '100%',
    height = '100%',
    vertical_align = 'Middle',
    horizontal_align = 'Center',
  }
end

---Build a color layer for overlay or solid background.
---@param color string Hex color (e.g., '#000000')
---@param opacity number Layer opacity (0.0-1.0)
---@return BackgroundLayer
local function make_color_layer(color, opacity)
  ---@type BackgroundLayer
  return {
    source = { Color = color },
    opacity = opacity,
    width = '120%',
    height = '120%',
    horizontal_offset = '-10%',
    vertical_offset = '-10%',
  }
end

---Get background color from active color scheme.
---@source https://wezterm.org/config/lua/wezterm/get_builtin_color_schemes.html
---@param window Window
---@return string Color hex (e.g., '#000000')
local function get_scheme_background_color(window)
  local scheme_name = window:effective_config().color_scheme
  if not scheme_name then
    return '#000000'
  end

  local scheme = wezterm.color.get_builtin_schemes()[scheme_name]
  if not scheme then
    return '#000000'
  end

  return scheme.background or '#000000'
end

-------------------------------------------------------------------------------
-- Apply State to Window
-------------------------------------------------------------------------------

---Apply current wallpaper state to a window.
---Uses `window:set_config_overrides()` to set per-window background layers.
---@param window Window
local function apply(window)
  local state = get_state()
  local overrides = window:get_config_overrides() or {}

  -- Capture baseline opacity on first apply (if not already captured)
  if state.base_window_background_opacity == nil then
    local effective = window:effective_config()
    local baseline = effective.window_background_opacity
    set_state({ base_window_background_opacity = baseline })
    state.base_window_background_opacity = baseline
  end

  -- Resolve scheme background once (used in both enabled/disabled cases)
  local scheme_bg = get_scheme_background_color(window)

  if state.image ~= '' then
    -- Wallpaper enabled: image layer + color overlay for scheme blending
    overrides.background = {
      make_image_layer(state.image, state.brightness),
      make_color_layer(scheme_bg, state.overlay_opacity),
    }
  else
    -- Wallpaper disabled: solid color matching scheme
    overrides.background = { make_color_layer(scheme_bg, state.base_window_background_opacity) }
  end

  window:set_config_overrides(overrides)
end

-------------------------------------------------------------------------------
-- Pickers / Menus
-------------------------------------------------------------------------------

---Show the image selection submenu.
---@param window Window
---@param pane Pane
local function show_image_picker(window, pane)
  local images = get_images()

  if #images == 0 then
    wezterm.log_warn('No images found in ' .. get_wallpapers_dir())
    return
  end

  local choices = {}
  for _, path in ipairs(images) do
    table.insert(choices, { label = basename(path), id = path })
  end

  window:perform_action(
    act.InputSelector({
      title = 'Select Wallpaper',
      choices = choices,
      fuzzy = true,
      fuzzy_description = 'Search images: ',
      action = wezterm.action_callback(function(win, _, id, _)
        if id then
          set_state({ image = id })
          apply(win)
        end
      end),
    }),
    pane
  )
end

---Show numeric input prompt with validation.
---User enters percentage, stored as decimal (value / 100).
---@param window Window
---@param pane Pane
---@param opts NumericInputOpts
---@param error_msg string|nil
local function show_numeric_input(window, pane, opts, error_msg)
  local state = get_state()
  local current_percent = math.floor(state[opts.state_key] * 100)

  local description = string.format(
    '%s (current: %d%%, range: %d-%d%%)',
    opts.title,
    current_percent,
    opts.min,
    opts.max
  )
  if error_msg then
    description = description
      .. '\n'
      .. wezterm.format({
        { Foreground = { AnsiColor = 'Red' } },
        { Text = error_msg },
      })
  end

  window:perform_action(
    act.PromptInputLine({
      description = description,
      action = wezterm.action_callback(function(win, p, line)
        if not line or line == '' then
          return
        end

        local num = tonumber(line)
        if not num then
          show_numeric_input(win, p, opts, 'Invalid: enter a number')
          return
        end

        if num < opts.min or num > opts.max then
          show_numeric_input(
            win,
            p,
            opts,
            string.format('Invalid: must be %d-%d', opts.min, opts.max)
          )
          return
        end

        local rounded_percent = math.floor(num + 0.5)
        set_state({ [opts.state_key] = rounded_percent / 100 })
        apply(win)
      end),
    }),
    pane
  )
end

---Disable wallpaper and restore original background.
---@param window Window
local function disable_wallpaper(window)
  set_state({ image = '' })
  apply(window)
end

---Show the main wallpaper settings menu.
---
---Intended to be called from a keybinding action callback.
---@param window Window
---@param pane Pane
function M.show_picker(window, pane)
  local state = get_state()

  -- Build dynamic labels showing current values
  local brightness_label = string.format('Brightness: %.0f%%', state.brightness * 100)
  local overlay_label = string.format('Overlay: %.0f%%', state.overlay_opacity * 100)

  local choices = {
    { label = 'Select image', id = 'select' },
    { label = brightness_label, id = 'brightness' },
    { label = overlay_label, id = 'overlay' },
    { label = 'Disable', id = 'disable' },
  }

  window:perform_action(
    act.InputSelector({
      title = 'Wallpaper Settings',
      choices = choices,
      action = wezterm.action_callback(function(win, p, id, _)
        if not id then
          return
        end

        if id == 'select' then
          show_image_picker(win, p)
        elseif id == 'brightness' then
          show_numeric_input(
            win,
            p,
            { title = 'Brightness', state_key = 'brightness', min = 0, max = 100 }
          )
        elseif id == 'overlay' then
          show_numeric_input(
            win,
            p,
            { title = 'Overlay', state_key = 'overlay_opacity', min = 0, max = 100 }
          )
        elseif id == 'disable' then
          disable_wallpaper(win)
        end
      end),
    }),
    pane
  )
end

return M
