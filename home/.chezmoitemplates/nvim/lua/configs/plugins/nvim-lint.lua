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

local function auto_lint(bufnr)
  if not enabled then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ft = vim.bo[bufnr].filetype
  local ft_linters = linters_by_ft[ft]

  if not ft_linters or #ft_linters == 0 then
    return
  end

  local lint_on_save = lint_on_save_by_ft[ft]

  if lint_on_save == false then
    return
  end

  vim.api.nvim_buf_call(bufnr, function()
    lint.try_lint()
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
  lint.try_lint()
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
