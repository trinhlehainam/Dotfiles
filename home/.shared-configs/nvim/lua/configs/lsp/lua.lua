---@type dotfiles.lsp.Language
return {
  parsers = { 'lua' },
  tools = { 'lua-language-server', 'stylua' },
  servers = {
    lua_ls = {
      settings = {
        Lua = {
          completion = { callSnippet = 'Replace' },
          codeLens = { enable = true },
        },
      },
    },
  },
  formatters = { lua = { 'stylua' } },
}
