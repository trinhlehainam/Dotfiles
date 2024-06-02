-- Ref: https://github.com/KevinSilvester/wezterm-config

-- require('utils.backdrops'):set_files():random()

require("events.gui-startup").setup()
-- require("events.gui-attached").setup()
require("events.right-status").setup()
require("events.left-status").setup()
require("events.tab-title").setup()
require("events.new-tab-button").setup()

local config = require("config")
	:init()
	:append(require("config.appearance"))
	:append(require("config.bindings"))
	:append(require("config.domains"))
	:append(require("config.fonts"))
	:append(require("config.general"))
	:append(require("config.launch"))

return config
