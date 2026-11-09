---@type dotfiles.lsp.Language
return {
  filetypes = { 'json', 'jsonc' },
  server_tools = { jsonls = { 'json-lsp' } },
  parsers = { 'json' },
  tools = { 'json-lsp', 'jq' },
  servers = {
    jsonls = {
      before_init = function(_, config)
        config.settings.json.schemas = require('schemastore').json.schemas({
          extra = {
            {
              description = 'Komorebi JSON schema',
              fileMatch = { 'komorebi.json' },
              name = 'komorebi.json',
              url = 'https://raw.githubusercontent.com/LGUG2Z/komorebi/master/schema.json',
            },
          },
        })
      end,
      settings = {
        json = {
          validate = { enable = true },
        },
      },
    },
  },
  formatters = { json = { 'jq' } },
}
