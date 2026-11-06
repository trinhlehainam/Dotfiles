---@type dotfiles.lsp.Language
return {
  filetypes = { 'css', 'scss', 'less' },
  server_tools = { cssls = { 'css-lsp' } },
  parsers = { 'css' },
  tools = { 'css-lsp' },
  servers = { cssls = {} },
}
