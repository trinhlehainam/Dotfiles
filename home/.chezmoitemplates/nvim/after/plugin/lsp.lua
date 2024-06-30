if vim.g.vscode then
	return
end

local after_masonlsp_setups = require("configs.lsp").after_masonlsp_setups

for _, after_masonlsp_setup in ipairs(after_masonlsp_setups) do
	if type(after_masonlsp_setup) == "function" then
		after_masonlsp_setup()
	end
end
