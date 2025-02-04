local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

local docker_compose_language_service = LspConfig:new('docker_compose_language_service')
M.lspconfigs = { docker_compose_language_service }

M.after_masonlsp_setup = function()
  -- NOTE: need to set filetype for docker-compose can detect
  -- https://github.com/neovim/neovim/discussions/26571
  -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#docker_compose_language_service
  vim.filetype.add({
    filename = {
      ['docker-compose.yml'] = 'yaml.docker-compose',
      ['docker-compose.yaml'] = 'yaml.docker-compose',
      ['compose.yml'] = 'yaml.docker-compose',
      ['compose.yaml'] = 'yaml.docker-compose',
    },
  })
end
return M
