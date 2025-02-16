local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

local log = require('utils.log')

M.treesitter.filetypes = { 'powershell' }

if vim.fn.executable('powershell') == 0 or vim.fn.executable('pwsh') == 0 then
  -- https://github.com/PowerShell/PowerShellEditorServices?tab=readme-ov-file#supported-powershell-versions
  log.warn('PowerShellEditorServices requires PowerShell to be installed')
  return M
end

M.lspconfigs = { LspConfig:new('powershell_es') }

return M

-- TODO: configure DAP
-- https://github.com/TheLeoP/powershell.nvim?tab=readme-ov-file#dap
--
