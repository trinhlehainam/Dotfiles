local ok_lint, lint = pcall(require, 'lint')
if not ok_lint then
  return
end

local log = require('utils.log')

-- Load linters configuration (do not hard-fail)
local linters = {}
local ok_lsp, lsp_config = pcall(require, 'configs.lsp')
if ok_lsp then
  linters = lsp_config.linters or {}
else
  log.warn('Failed to load configs.lsp for nvim-lint - using defaults', 'nvim-lint')
end

-- Build config maps
local linters_by_ft = {}
local lint_on_save_by_ft = {}

for _, config in ipairs(linters) do
  local by_ft = config.linters_by_ft
  if by_ft then
    for filetype, ft_linters in pairs(by_ft) do
      if linters_by_ft[filetype] == nil then
        linters_by_ft[filetype] = ft_linters
        lint_on_save_by_ft[filetype] = config.lint_on_save ~= false
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

vim.api.nvim_create_user_command('Lint', function()
  lint.try_lint()
end, { desc = 'Run linters for current buffer' })

local function set_enabled(value)
  enabled = value
  log.info('Auto linting ' .. (enabled and 'enabled' or 'disabled'), 'nvim-lint')
end

vim.api.nvim_create_user_command('LintEnable', function()
  set_enabled(true)
end, { desc = 'Enable auto linting globally' })

vim.api.nvim_create_user_command('LintDisable', function()
  set_enabled(false)
end, { desc = 'Disable auto linting globally' })

vim.api.nvim_create_user_command('LintToggle', function()
  set_enabled(not enabled)
end, { desc = 'Toggle auto linting globally' })
