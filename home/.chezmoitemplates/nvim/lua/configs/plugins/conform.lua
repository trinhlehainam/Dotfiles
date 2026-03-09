local log = require('utils.log')
local project_settings = require('configs.project_settings')

-- Safely load formatters configuration
local ok, lsp_config = pcall(require, 'configs.lsp')
if not ok then
  log.warn('Failed to load configs.lsp module for conform.nvim')
  return
end

local formatters = lsp_config.formatters or {}

local formatters_by_ft = {}

local function merge_unique(base, extra)
  local merged = vim.deepcopy(base or {})
  local seen = {}

  for _, name in ipairs(merged) do
    seen[name] = true
  end

  for _, name in ipairs(extra or {}) do
    if not seen[name] then
      seen[name] = true
      table.insert(merged, name)
    end
  end

  return merged
end

for _, formatter in ipairs(formatters) do
  if type(formatter.formatters_by_ft) == 'table' then
    formatters_by_ft = vim.tbl_extend('keep', formatters_by_ft, formatter.formatters_by_ft)
  end
end

local base_star_formatters = vim.deepcopy(formatters_by_ft['*'] or {})
formatters_by_ft['*'] = function(bufnr)
  project_settings.ensure_conform_overrides(bufnr)
  return merge_unique(base_star_formatters, project_settings.get_project_formatters(bufnr))
end

require('conform').setup({
  notify_on_error = false,
  format_on_save = function(bufnr)
    project_settings.ensure_conform_overrides(bufnr)

    local tooling_format_on_save = project_settings.get_tooling_format_on_save(bufnr)
    if tooling_format_on_save == false then
      return nil
    end

    local editor_format_on_save = project_settings.get_editor_format_on_save(bufnr)
    if tooling_format_on_save == nil and editor_format_on_save == false then
      return nil
    end

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
