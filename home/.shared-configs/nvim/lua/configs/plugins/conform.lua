local common = require('utils.common')
local project = require('configs.project')
local formatters_by_ft = vim.deepcopy(require('configs.lsp').formatters)

local base_star_formatters = vim.deepcopy(formatters_by_ft['*'] or {})
formatters_by_ft['*'] = function(bufnr)
  return common.merge_unique_strings(base_star_formatters, project.get_project_formatters(bufnr))
end

require('conform').setup({
  notify_on_error = false,
  format_on_save = function(bufnr)
    local tooling_format_on_save = project.get_tooling_format_on_save(bufnr)
    if tooling_format_on_save == false then
      return nil
    end

    local editor_format_on_save = project.get_editor_format_on_save(bufnr)
    if tooling_format_on_save == nil and editor_format_on_save == false then
      return nil
    end

    -- C/C++ formatting stays opt-in through an explicit formatter.
    local disable_filetypes = { c = true, cpp = true }
    return {
      timeout_ms = 500,
      lsp_format = disable_filetypes[vim.bo[bufnr].filetype] and 'never' or 'fallback',
    }
  end,
  formatters_by_ft = formatters_by_ft,
})
