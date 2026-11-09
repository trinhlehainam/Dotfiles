---@type dotfiles.lsp.Language
return {
  filetypes = { 'awk' },
  server_tools = { awk_ls = { 'awk-language-server' } },
  parsers = { 'awk' },
  tools = { 'awk-language-server' },
  servers = { awk_ls = {} },
}
