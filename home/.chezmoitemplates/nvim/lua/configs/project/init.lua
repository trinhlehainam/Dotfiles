local log = require('utils.log')
local editor = require('configs.project.editor')
local project_json = require('configs.project.json')
local tooling = require('configs.project.tooling')

local M = {}

local TITLE = 'project-settings'
local setup_done = false

local function create_reload_command()
  local ok, err = pcall(vim.api.nvim_create_user_command, 'ProjectSettingsReload', function()
    project_json.invalidate()
    editor.invalidate()
    tooling.invalidate()

    -- Refresh open buffers after invalidation so filetype associations and
    -- buffer-local editor options reflect the new JSON immediately.
    editor.refresh_open_buffers()

    local message = 'Project settings reloaded'
    if #vim.lsp.get_clients() > 0 then
      message = message .. '; restart LSP clients to reload local server settings'
    end
    log.info(message, TITLE)
  end, { desc = 'Reload project-local JSON settings' })

  if not ok and not tostring(err):match('E174') then
    log.warn(('Failed to create :ProjectSettingsReload: %s'):format(tostring(err)), TITLE)
  end
end

function M.setup()
  if setup_done then
    return
  end

  create_reload_command()
  editor.setup(vim.api.nvim_create_augroup('project-settings', { clear = true }))
  setup_done = true
end

M.ensure_conform_overrides = tooling.ensure_conform_overrides
M.ensure_lint_overrides = tooling.ensure_lint_overrides
M.get_project_formatters = tooling.get_formatters
M.get_project_linters = tooling.get_linters
M.get_editor_format_on_save = editor.get_format_on_save
M.get_tooling_format_on_save = tooling.get_format_on_save
M.get_tooling_lint_on_save = tooling.get_lint_on_save

return M
