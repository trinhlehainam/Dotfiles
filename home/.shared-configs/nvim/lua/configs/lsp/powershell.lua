---@type dotfiles.lsp.Language
local M = { parsers = { 'powershell' } }

if vim.fn.executable('powershell') == 0 and vim.fn.executable('pwsh') == 0 then
  require('utils.log').warn('PowerShellEditorServices requires PowerShell to be installed')
  return M
end

-- powershell.nvim owns server startup.
M.tools = { 'powershell-editor-services' }
return M
