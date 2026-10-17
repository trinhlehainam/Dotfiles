---@type dotfiles.lsp.Language
return {
  parsers = { 'nu' },
  -- Native LSP checks the executable when it starts a Nushell buffer.
  servers = { nushell = {} },
}
