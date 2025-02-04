local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'json' }

M.formatterconfig.servers = { 'jq' }
M.formatterconfig.formatters_by_ft = {
  json = { 'jq' },
}

local jsonls = LspConfig:new('jsonls')
jsonls.server = 'jsonls'
jsonls.settings = {
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
}

M.lspconfigs = { jsonls }

return M
