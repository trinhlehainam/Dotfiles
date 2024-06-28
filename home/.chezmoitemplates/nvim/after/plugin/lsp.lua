if vim.g.vscode then
	return
end

local language_settings = require("configs.lsp").language_settings

for _, settings in pairs(language_settings) do
	if type(settings.after_masonlsp_setup) == "function" then
		settings.after_masonlsp_setup()
	end
end
