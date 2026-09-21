---@type dotfiles.lsp.Language
return {
  parsers = { 'rust', 'toml' },
  -- Rustaceanvim owns LSP and debugger setup; Mason only installs the tools.
  tools = { 'rust-analyzer', 'codelldb' },
  neotest = function()
    return require('rustaceanvim.neotest')
  end,
}
