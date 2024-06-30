local mason_utils = require("utils.mason")
local conform = require("conform")

local formatters = require("configs.lsp").formatters
local ensure_installed_formatters = { "stylua" }

for _, formatter in ipairs(formatters) do
	if vim.islist(formatter.servers) then
		vim.list_extend(ensure_installed_formatters, formatter.servers)
	end
end

local formatters_by_ft = { lua = { "stylua" } }

for _, formatter in ipairs(formatters) do
	if type(formatter.formatters_by_ft) == "table" then
		formatters_by_ft = vim.tbl_extend("keep", formatters_by_ft, formatter.formatters_by_ft)
	end
end

mason_utils.install(ensure_installed_formatters)

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
