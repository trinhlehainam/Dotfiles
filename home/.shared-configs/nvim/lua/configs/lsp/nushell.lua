---@type dotfiles.lsp.Language
return {
  filetypes = { 'nu' },
  parsers = { 'nu' },
  -- Native LSP checks the executable when it starts a Nushell buffer.
  servers = { nushell = {} },
}
