---@type dotfiles.lsp.Language
return {
  filetypes = { 'lua' },
  server_tools = { lua_ls = { 'lua-language-server' } },
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
