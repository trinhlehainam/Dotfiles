-- Safely load the lint plugin
local ok_lint, lint = pcall(require, 'lint')
if not ok_lint then
  -- Plugin not installed, skip setup
  return
end

local log = require('utils.log')

-- Safely load linters configuration
-- Don't return on failure - use defaults instead
local linters = {}
local ok_lsp, lsp_config = pcall(require, 'configs.lsp')
if ok_lsp then
  linters = lsp_config.linters or {}
else
  log.warn('Failed to load configs.lsp module for nvim-lint - using defaults')
end

local linters_by_ft = {}

for _, linter in ipairs(linters) do
  if type(linter.linters_by_ft) == 'table' then
    linters_by_ft = vim.tbl_extend('keep', linters_by_ft, linter.linters_by_ft)
  end
end

lint.linters_by_ft = linters_by_ft

-- BUG: https://github.com/mfussenegger/nvim-lint/issues/462
-- if vim.tbl_contains(ensure_installed_linters, "eslint_d") then
-- 	local eslint_d = lint.linters.eslint_d
--
-- 	eslint_d.args = {
-- 		"--no-warn-ignored", -- <-- this is the key argument
-- 		"--format",
-- 		"json",
-- 		"--stdin",
-- 		"--stdin-filename",
-- 		function()
-- 			return vim.api.nvim_buf_get_name(0)
-- 		end,
-- 	}
-- end

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
  callback = function()
    -- try_lint without arguments runs the linters defined in `linters_by_ft`
    -- for the current filetype
    require('lint').try_lint()
  end,
})
