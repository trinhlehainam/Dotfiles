---@type dotfiles.lsp.Language
local M = { parsers = { 'nu' } }

if vim.fn.executable('nu') == 0 then
  require('utils.log').info('Nushell is not installed')
  return M
end

M.servers = { nushell = {} }
return M
