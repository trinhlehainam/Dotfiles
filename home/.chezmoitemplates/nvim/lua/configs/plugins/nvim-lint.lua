-- ============================================================================
-- NVIM-LINT
-- ============================================================================
-- Auto-lint on save (BufWritePost).
--
-- Config:
-- - Comes from `configs.lsp` (each `configs.lsp.<lang>` contributes `linterconfig`).
-- - `lint_on_save` (default: true) can be set per module.
--
-- Merge rules (when multiple configs share a filetype):
-- - Linters are concatenated.
-- - `lint_on_save=false` disables auto-lint (false wins); we warn once on conflicts.
--
-- Commands: :Lint, :LintEnable, :LintDisable, :LintToggle
-- ============================================================================

local ok_lint, lint = pcall(require, 'lint')
if not ok_lint then
  -- nvim-lint is not installed, keep this config as a no-op
  return
end

local log = require('utils.log')
local common = require('utils.common')
local project_settings = require('configs.project_settings')

-- Load linter configuration (do not hard-fail)
local linters = {}
local ok_lsp, lsp_config = pcall(require, 'configs.lsp')
if ok_lsp then
  linters = lsp_config.linters or {}
else
  log.warn('Failed to load configs.lsp for nvim-lint - using defaults', 'nvim-lint')
end

-- Build config maps for nvim-lint
local linters_by_ft = {}
local lint_on_save_by_ft = {}
local warned_lint_on_save_conflicts = {}

for _, config in ipairs(linters) do
  local by_ft = config.linters_by_ft
  if by_ft then
    for filetype, ft_linters in pairs(by_ft) do
      local lint_on_save = config.lint_on_save ~= false
      if linters_by_ft[filetype] == nil then
        linters_by_ft[filetype] = vim.list_extend({}, ft_linters)
        lint_on_save_by_ft[filetype] = lint_on_save
      else
        if
          lint_on_save_by_ft[filetype] ~= lint_on_save
          and not warned_lint_on_save_conflicts[filetype]
        then
          warned_lint_on_save_conflicts[filetype] = true
          log.warn(
            ('Conflicting lint_on_save for filetype "%s"; auto-lint will be disabled if any config sets lint_on_save=false'):format(
              filetype
            ),
            'nvim-lint'
          )
        end
        linters_by_ft[filetype] = vim.list_extend(linters_by_ft[filetype], ft_linters)
        lint_on_save_by_ft[filetype] = lint_on_save_by_ft[filetype] and lint_on_save
      end
    end
  end
end

lint.linters_by_ft = linters_by_ft

-- State
local enabled = true
local group = vim.api.nvim_create_augroup('nvim-lint', { clear = true })

local function resolve_base_linters(filetype)
  local exact = linters_by_ft[filetype]
  if exact then
    return vim.deepcopy(exact)
  end

  local merged = {}
  for _, part in ipairs(vim.split(filetype, '.', { plain = true })) do
    merged = common.merge_unique_strings(merged, linters_by_ft[part] or {})
  end

  return merged
end

local function resolve_base_lint_on_save(filetype)
  if lint_on_save_by_ft[filetype] ~= nil then
    return lint_on_save_by_ft[filetype]
  end

  local lint_on_save = nil
  for _, part in ipairs(vim.split(filetype, '.', { plain = true })) do
    local value = lint_on_save_by_ft[part]
    if value ~= nil then
      lint_on_save = lint_on_save == nil and value or (lint_on_save and value)
    end
  end

  return lint_on_save
end

local function linters_for_buf(bufnr)
  project_settings.ensure_lint_overrides(bufnr)
  return common.merge_unique_strings(
    resolve_base_linters(vim.bo[bufnr].filetype),
    project_settings.get_project_linters(bufnr)
  )
end

local function lint_on_save_enabled(bufnr)
  local tooling_lint_on_save = project_settings.get_tooling_lint_on_save(bufnr)
  if tooling_lint_on_save ~= nil then
    return tooling_lint_on_save
  end

  local base_lint_on_save = resolve_base_lint_on_save(vim.bo[bufnr].filetype)
  if base_lint_on_save ~= nil then
    return base_lint_on_save
  end

  return true
end

local function auto_lint(bufnr)
  if not enabled then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ft_linters = linters_for_buf(bufnr)
  if #ft_linters == 0 then
    return
  end

  if lint_on_save_enabled(bufnr) == false then
    return
  end

  vim.api.nvim_buf_call(bufnr, function()
    lint.try_lint(ft_linters)
  end)
end

vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  callback = function(args)
    auto_lint(args.buf)
  end,
})

---@param name string
---@param fn string|fun(args: vim.api.keyset.create_user_command.command_args)
---@param opts vim.api.keyset.user_command
local function create_user_command(name, fn, opts)
  -- Create a user command; ignore E174 on reload; warn on other failures.
  local ok, err = pcall(vim.api.nvim_create_user_command, name, fn, opts)
  if not ok and not tostring(err):match('E174') then
    log.warn(('Failed to create command :%s: %s'):format(name, tostring(err)), 'nvim-lint')
  end
end

create_user_command('Lint', function()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft_linters = linters_for_buf(bufnr)
  if #ft_linters == 0 then
    return
  end

  lint.try_lint(ft_linters)
end, { desc = 'Run linters for current buffer' })

local function set_enabled(value)
  enabled = value
  log.info('Auto linting ' .. (enabled and 'enabled' or 'disabled'), 'nvim-lint')
end

create_user_command('LintEnable', function()
  set_enabled(true)
end, { desc = 'Enable auto linting globally' })

create_user_command('LintDisable', function()
  set_enabled(false)
end, { desc = 'Disable auto linting globally' })

create_user_command('LintToggle', function()
  set_enabled(not enabled)
end, { desc = 'Toggle auto linting globally' })
