---@type dotfiles.lsp.Language
return {
  parsers = { 'awk' },
  tools = { 'awk-language-server' },
  servers = { awk_ls = {} },
}
