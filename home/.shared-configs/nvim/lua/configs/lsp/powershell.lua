---@type dotfiles.lsp.Language
local M = { parsers = { 'powershell' } }

if
  vim.fn.executable('pwsh') == 0
  and not (require('utils.common').IS_WINDOWS and vim.fn.executable('powershell') == 1)
then
  return M
end

-- powershell.nvim owns server startup.
M.tools = { 'powershell-editor-services' }
return M
