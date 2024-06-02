local wezterm = require("wezterm")
local M = {}

M.setup = function()
	wezterm.on("gui-attached", function(domain)
		-- maximize all displayed windows on startup
		local workspace = wezterm.mux.get_active_workspace()
		for _, window in ipairs(mux.all_windows()) do
			if window:get_workspace() == workspace then
				window:gui_window():maximize()
			end
		end
	end)
end

return config
