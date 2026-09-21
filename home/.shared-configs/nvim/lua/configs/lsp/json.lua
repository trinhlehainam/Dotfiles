---@type dotfiles.lsp.Language
return {
  parsers = { 'json' },
  tools = { 'json-lsp', 'jq' },
  servers = {
    jsonls = {
      settings = {
        json = {
          schemas = require('schemastore').json.schemas({
            extra = {
              {
                description = 'Komorebi JSON schema',
                fileMatch = { 'komorebi.json' },
                name = 'komorebi.json',
                url = 'https://raw.githubusercontent.com/LGUG2Z/komorebi/master/schema.json',
              },
            },
          }),
          validate = { enable = true },
        },
      },
    },
  },
  formatters = { json = { 'jq' } },
}
