local wezterm = require('wezterm') ---@type Wezterm

---@type Fonts
local font = wezterm.font_with_fallback({
  { family = 'JetBrainsMono Nerd Font', weight = 'Thin' },
})

return {
  font = font,
  font_size = 12.0,
  line_height = 1,
  cell_width = 1,
  use_cap_height_to_scale_fallback_fonts = true,
  allow_square_glyphs_to_overflow_width = 'WhenFollowedBySpace',

  freetype_load_target = 'Light',
  freetype_render_target = 'HorizontalLcd',
}
