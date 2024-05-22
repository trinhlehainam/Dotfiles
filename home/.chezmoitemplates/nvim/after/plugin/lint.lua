if vim.g.vscode then
	return
end

local hasmason, mason_installer = pcall(require, "utils.mason_installer")

if not hasmason then
	require("utils.log").error("Cannot load mason installer")
	return
end

local haslint, lint = pcall(require, "lint")

if not haslint then
	require("utils.log").error("nvim-lint is not installed")
	return
end

local language_settings = require("configs.lsp").language_settings

local ensure_installed_linters = {}

for _, settings in pairs(language_settings) do
	if settings.linterconfig.servers ~= nil and vim.islist(settings.linterconfig.servers) then
		vim.list_extend(ensure_installed_linters, settings.linterconfig.servers)
	end
end

local linters_by_ft = {}

for _, settings in pairs(language_settings) do
	if settings.linterconfig.linters_by_ft ~= nil and type(settings.linterconfig.linters_by_ft) == "table" then
		vim.tbl_extend("force", linters_by_ft, settings.linterconfig.linters_by_ft)
	end
end

mason_installer.install(ensure_installed_linters)

lint.linters_by_ft = linters_by_ft

local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
	group = lint_augroup,
	callback = function()
		lint.try_lint()
	end,
})

vim.keymap.set("n", "<leader>ll", function()
	lint.try_lint()
end, { desc = "Trigger linting for current file" })
