---Wallpaper picker for WezTerm.
---
---Images live in `assets/wallpapers/` (relative to `wezterm.config_dir()`).
---
---When enabled, applies window overrides:
--- - `background` image + color overlay layers
--- - `window_background_opacity = 1.0`
---
---A keybinding is configured in `config/wallpaper.lua` (default: `CTRL+SHIFT+B`).
---
---@module utils.wallpaper
---@source https://wezterm.org/config/lua/config/background.html
---@source https://wezterm.org/config/lua/keyassignment/InputSelector.html
---@source https://github.com/sunbearc22/sb_show_wallpapers.wezterm/blob/main/plugin/init.lua
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
---@field image string|nil Current wallpaper path; `nil` means disabled
---@field brightness number Brightness multiplier (0.0-1.0)
---@field overlay_opacity number Opacity of the color overlay (0.0-1.0)
---@field base_window_background_opacity number|nil Cached baseline window opacity

---Options for the preset picker menu.
---@class PresetPickerOpts
---@field title string Menu title displayed in the picker
---@field presets number[] Array of preset values to choose from
---@field state_key string Numeric key in WallpaperState to update (e.g., "brightness")
---@field format string Format string for displaying values (e.g., "%.0f%%")

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

---Brightness preset values.
local BRIGHTNESS_PRESETS = { 0.1, 0.2, 0.3, 0.5 }

---Overlay opacity preset values.
local OVERLAY_OPACITY_PRESETS = { 0.85, 0.9, 0.95 }

-------------------------------------------------------------------------------
-- State Management
-------------------------------------------------------------------------------

---Default wallpaper state values.
---@type WallpaperState
local DEFAULT_STATE = {
  image = nil,
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
---@field image? string|nil
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

---Find index of a path in the images list.
---@param images string[]
---@param path string|nil
---@return number|nil
local function find_index(images, path)
  if not path then
    return nil
  end
  for i, img in ipairs(images) do
    if img == path then
      return i
    end
  end
  return nil
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
---@return table
local function make_layer(path, brightness)
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

---Build a color overlay layer that tints the wallpaper using the scheme background.
---@param color string
---@param opacity number
---@return table
local function make_overlay_layer(color, opacity)
  return {
    source = { Color = color },
    opacity = opacity,
    width = '120%',
    height = '120%',
    horizontal_offset = '-10%',
    vertical_offset = '-10%',
  }
end

-------------------------------------------------------------------------------
-- Apply State to Window
-------------------------------------------------------------------------------

---Apply current wallpaper state to a window.
---
---Uses `window:set_config_overrides()` to set per-window overrides.
---When enabled, forces `window_background_opacity=1.0` to avoid double-dimming
---the wallpaper image (from both translucency and HSB brightness).
---@param window Window
local function apply(window)
  local state = get_state()
  local overrides = window:get_config_overrides() or {}

  if state.image then
    -- Capture baseline opacity on first wallpaper set (if not already captured)
    if state.base_window_background_opacity == nil then
      local effective = window:effective_config()
      set_state({ base_window_background_opacity = effective.window_background_opacity })
    end

    -- Set background layers and force full window opacity
    local effective = window:effective_config()
    local scheme_bg = (effective.colors and effective.colors.background) or '#000000'

    overrides.background = {
      make_layer(state.image, state.brightness),
      make_overlay_layer(scheme_bg, state.overlay_opacity),
    }
    overrides.window_background_opacity = 1.0
  else
    -- Disable wallpaper: clear background, restore original opacity
    overrides.background = nil
    local base = get_state().base_window_background_opacity
    overrides.window_background_opacity = base
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

---Show a preset picker for numeric values (e.g., brightness).
---
---Displays an InputSelector menu with preset values. The current value
---is marked with "(current)" suffix. On selection, updates the specified
---state key and re-applies the wallpaper.
---@param window Window WezTerm window object
---@param pane Pane WezTerm pane object
---@param opts PresetPickerOpts Picker configuration options
local function show_preset_picker(window, pane, opts)
  local state = get_state()
  local choices = {}

  for _, value in ipairs(opts.presets) do
    local label = string.format(opts.format, value * 100)
    if state[opts.state_key] == value then
      label = label .. ' (current)'
    end
    table.insert(choices, { label = label, id = tostring(value) })
  end

  window:perform_action(
    act.InputSelector({
      title = opts.title,
      choices = choices,
      action = wezterm.action_callback(function(win, _, id, _)
        if id then
          set_state({ [opts.state_key] = tonumber(id) })
          apply(win)
        end
      end),
    }),
    pane
  )
end

---Rotate to next or previous image.
---@param window Window
---@param direction number 1 for next, -1 for previous
local function rotate_image(window, direction)
  local images = get_images()
  if #images == 0 then
    wezterm.log_warn('No images found in ' .. get_wallpapers_dir())
    return
  end

  local state = get_state()
  local current_idx = find_index(images, state.image) or 0
  local new_idx = ((current_idx - 1 + direction) % #images) + 1

  set_state({ image = images[new_idx] })
  apply(window)
end

---Disable wallpaper and restore original background.
---@param window Window
local function disable_wallpaper(window)
  set_state({ image = nil })
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
    { label = 'Select image...', id = 'select' },
    { label = 'Next', id = 'next' },
    { label = 'Previous', id = 'prev' },
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
        elseif id == 'next' then
          rotate_image(win, 1)
        elseif id == 'prev' then
          rotate_image(win, -1)
        elseif id == 'brightness' then
          show_preset_picker(win, p, {
            title = 'Brightness',
            presets = BRIGHTNESS_PRESETS,
            state_key = 'brightness',
            format = '%.0f%%',
          })
        elseif id == 'overlay' then
          show_preset_picker(win, p, {
            title = 'Overlay Opacity',
            presets = OVERLAY_OPACITY_PRESETS,
            state_key = 'overlay_opacity',
            format = '%.0f%%',
          })
        elseif id == 'disable' then
          disable_wallpaper(win)
        end
      end),
    }),
    pane
  )
end

return M
