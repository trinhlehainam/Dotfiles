local lint = require('lint')
local log = require('utils.log')
local common = require('utils.common')
local project = require('configs.project')
local registry = require('configs.lsp')
local linters_by_ft = registry.linters
local lint_on_save_by_ft = registry.lint_on_save

lint.linters_by_ft = linters_by_ft

local enabled = true
local group = vim.api.nvim_create_augroup('nvim-lint', { clear = true })

---Use an exact filetype match, otherwise merge components (e.g. yaml.ansible).
---@param filetype string
---@return string[]
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

---An exact policy wins; otherwise any component's false disables automatic linting.
---@param filetype string
---@return boolean? policy Nil leaves the default policy unchanged.
local function resolve_base_lint_on_save(filetype)
  if lint_on_save_by_ft[filetype] ~= nil then
    return lint_on_save_by_ft[filetype]
  end

  local lint_on_save = nil
  for _, part in ipairs(vim.split(filetype, '.', { plain = true })) do
    local value = lint_on_save_by_ft[part]
    if value ~= nil then
      if lint_on_save == nil then
        lint_on_save = value
      else
        lint_on_save = lint_on_save and value
      end
    end
  end

  return lint_on_save
end

---Project linters extend language defaults without duplicates.
---@param bufnr integer
---@return string[]
local function linters_for_buf(bufnr)
  return common.merge_unique_strings(
    resolve_base_linters(vim.bo[bufnr].filetype),
    project.get_project_linters(bufnr)
  )
end

---Project policy overrides language policy; default to enabled.
---@param bufnr integer
---@return boolean
local function lint_on_save_enabled(bufnr)
  local tooling_lint_on_save = project.get_tooling_lint_on_save(bufnr)
  if tooling_lint_on_save ~= nil then
    return tooling_lint_on_save
  end

  local base_lint_on_save = resolve_base_lint_on_save(vim.bo[bufnr].filetype)
  if base_lint_on_save ~= nil then
    return base_lint_on_save
  end

  return true
end

---Run in the written buffer because lint.try_lint uses the current buffer.
---@param bufnr integer
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
  -- E174 means the command already exists after a reload.
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

---@param value boolean
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
