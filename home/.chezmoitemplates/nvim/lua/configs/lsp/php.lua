local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.lspconfig.server = "phpactor"
M.lspconfig.use_setup = true

M.formatterconfig.servers = { "blade-formatter" }
M.formatterconfig.formatters_by_ft = {
	blade = { "blade-formatter" },
}

M.lspconfig.setup = function(capabilities, on_attach)
	-- NOTE: laravel.nvim use lspconfig to detect installed servers
	-- Need to set up lspconfig first
	require("lspconfig")[M.lspconfig.server].setup({
		capabilities = capabilities,
		on_attach = on_attach,
	})
end

M.after_lspconfig = function()
	local haslaravel, laravel = pcall(require, "laravel")
	local log = require("utils.log")

	if not haslaravel then
		log.error("laravel.nvim is not installed")
		return
	end

	laravel.setup()

	vim.keymap.set("n", "<leader>la", ":Laravel artisan<cr>", { desc = "[L]aravel [A]rtisan" })
	vim.keymap.set("n", "<leader>lm", ":Laravel related<cr>", { desc = "[L]aravel [R]elated" })
	local haslaravelext, laravelext = pcall(require("telescope").load_extension, "laravel")
	if haslaravelext then
		vim.keymap.set("n", "<leader>lr", laravelext.routes, { desc = "Find [L]aravel [R]outes" })
	end
end

return M
