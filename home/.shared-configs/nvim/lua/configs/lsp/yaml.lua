---@type dotfiles.lsp.Language
return {
  parsers = { 'yaml' },
  tools = { 'yaml-language-server' },
  servers = {
    yamlls = {
      -- NOTE: yaml.docker-compose has its own lsp config, not use yamlls
      -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#yamlls
      filetypes = { 'yaml', 'yaml.gitlab' },
      settings = {
        yaml = {
          schemaStore = {
            -- You must disable built-in schemaStore support if you want to use
            -- this plugin and its advanced options like `ignore`.
            enable = false,
            -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
            url = '',
          },
          schemas = require('schemastore').yaml.schemas(),
        },
      },
    },
  },
}
