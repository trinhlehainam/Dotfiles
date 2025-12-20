local wezterm = require('wezterm') ---@type Wezterm
local mux = wezterm.mux

return function()
  wezterm.on('gui-startup', function(cmd)
    local _, _, window = mux.spawn_window(cmd or {})
    window:gui_window():maximize()
  end)
end
