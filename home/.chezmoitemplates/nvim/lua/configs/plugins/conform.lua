local log = require('utils.log')

-- Safely load formatters configuration
local ok, lsp_config = pcall(require, 'configs.lsp')
if not ok then
  log.warn('Failed to load configs.lsp module for conform.nvim')
  return
end

local formatters = lsp_config.formatters or {}

local formatters_by_ft = {}

for _, formatter in ipairs(formatters) do
  if type(formatter.formatters_by_ft) == 'table' then
    formatters_by_ft = vim.tbl_extend('keep', formatters_by_ft, formatter.formatters_by_ft)
  end
end

require('conform').setup({
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

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  callback = function(args)
    require('conform').format({ bufnr = args.buf })
  end,
})
