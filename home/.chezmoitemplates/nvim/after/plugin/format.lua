if vim.g.vscode then
	return
end

local hasmason, mason_installer = pcall(require, "utils.mason_installer")
local log = require("utils.log")

if not hasmason then
	log.error("Cannot load mason installer")
	return
end

local hasconform, conform = pcall(require, "conform")
if not hasconform then
	log.error("conform.nvim is not installed")
	return
end

local language_settings = require("configs.lsp").language_settings
local ensure_installed_formatters = { "stylua" }

for _, settings in pairs(language_settings) do
	if vim.islist(settings.formatterconfig.servers) then
		vim.list_extend(ensure_installed_formatters, settings.formatterconfig.servers)
	end
end

local formatters_by_ft = { lua = { "stylua" } }

for _, settings in pairs(language_settings) do
	if type(settings.formatterconfig.formatters_by_ft) == "table" then
		vim.tbl_extend("force", formatters_by_ft, settings.formatterconfig.formatters_by_ft)
	end
end

mason_installer.install(ensure_installed_formatters)

conform.setup({
	notify_on_error = false,
	format_on_save = function(bufnr)
		-- Disable "format_on_save lsp_fallback" for languages that don't
		-- have a well standardized coding style. You can add additional
		-- languages here or re-enable it for the disabled ones.
		local disable_filetypes = { c = true, cpp = true }
		return {
			timeout_ms = 500,
			lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
		}
	end,
	formatters_by_ft = formatters_by_ft,
})
