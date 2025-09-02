local lint = require('lint')
local log = require('utils.log')

-- Safely load linters configuration
local ok, lsp_config = pcall(require, 'configs.lsp')
if not ok then
  log.warn('Failed to load configs.lsp module for nvim-lint')
  return
end

local linters = lsp_config.linters or {}

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

local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
  group = lint_augroup,
  callback = function()
    lint.try_lint()
  end,
})

vim.keymap.set('n', '<leader>ll', function()
  lint.try_lint()
end, { desc = '[T]ry [L]inting for current file' })
