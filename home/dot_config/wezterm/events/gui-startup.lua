local wezterm = require("wezterm")

local M = {}

M.setup = function()
	wezterm.on("gui-startup", function(cmd)
		local _, _, window = wezterm.mux.spawn_window(cmd or {})
		window:gui_window():maximize()
	end)
end

return M
