if vim.g.vscode then
	return
end

local hasmason, mason_installer = pcall(require, "utils.mason_installer")
local log = require("utils.log")

if not hasmason or mason_installer.install == nil then
	log.error("Cannot load mason installer")
	return
end

local haslint, lint = pcall(require, "lint")

if not haslint then
	log.error("nvim-lint is not installed")
	return
end

local language_settings = require("configs.lsp").language_settings

--- @type string[]
local ensure_installed_linters = {}

for _, settings in pairs(language_settings) do
	if vim.islist(settings.linterconfig.servers) then
		vim.list_extend(ensure_installed_linters, settings.linterconfig.servers)
	end
end

local linters_by_ft = {}

for _, settings in pairs(language_settings) do
	if type(settings.linterconfig.linters_by_ft) == "table" then
		linters_by_ft = vim.tbl_extend("keep", linters_by_ft, settings.linterconfig.linters_by_ft)
	end
end

mason_installer.install(ensure_installed_linters)

lint.linters_by_ft = linters_by_ft

-- BUG: https://github.com/mfussenegger/nvim-lint/issues/462
-- if vim.tbl_contains(ensure_installed_linters, "eslint_d") then
-- 	local eslint_d = lint.linters.eslint_d
--
-- 	eslint_d.args = {
-- 		"--no-warn-ignored", -- <-- this is the key argument
-- 		"--format",
-- 		"json",
-- 		"--stdin",
-- 		"--stdin-filename",
-- 		function()
-- 			return vim.api.nvim_buf_get_name(0)
-- 		end,
-- 	}
-- end

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
