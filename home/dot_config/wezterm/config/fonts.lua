local wezterm = require('wezterm') ---@type Wezterm

---@type Fonts
local font = wezterm.font_with_fallback({
  { family = 'JetBrainsMono Nerd Font', weight = 'Thin' },
})

---@type ConfigModule
return {
  apply_to_config = function(config)
    config.font = font
    config.font_size = 12.0
    config.line_height = 1
    config.cell_width = 1
    config.use_cap_height_to_scale_fallback_fonts = true
    config.allow_square_glyphs_to_overflow_width = 'WhenFollowedBySpace'

    config.freetype_load_target = 'Light'
    config.freetype_render_target = 'HorizontalLcd'
  end,
}
