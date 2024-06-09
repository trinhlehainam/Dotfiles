local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

M.treesitter.filetypes = { "php" }

local log = require("utils.log")
local utils = require("utils.common")
if utils.IS_WINDOWS and not utils.IS_WSL then
	log.info("php lsp setup only available on unix")
	return
end

M.lspconfig.server = "phpactor"
M.lspconfig.use_masonlsp_setup = true

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

M.after_masonlsp_setup = function()
	local haslaravel, laravel = pcall(require, "laravel")

	if not haslaravel then
		log.error("laravel.nvim is not installed")
		return
	end

	laravel.setup({
		features = {
			null_ls = {
				enable = false,
			},
		},
	})

	vim.keymap.set("n", "<leader>la", ":Laravel artisan<cr>", { desc = "[L]aravel [A]rtisan" })
	vim.keymap.set("n", "<leader>lm", ":Laravel related<cr>", { desc = "[L]aravel [R]elated" })
	vim.keymap.set("n", "<leader>lr", ":Laravel routes<cr>", { desc = "Find [L]aravel [R]outes" })
end

return M
