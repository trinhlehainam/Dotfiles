require("configs.options")
require("configs.keymaps")

if vim.g.vscode then
	-- VSCode extension
	require("configs.vscode")
else
	-- configure Neovim plugins
	require("configs.lazy")
end
-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
