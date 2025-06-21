local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

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

local docker_compose_language_service = LspConfig:new('docker_compose_language_service', 'docker-compose-language-service')
local dockerls = LspConfig:new('dockerls', 'dockerfile-language-server')

M.lspconfigs = { docker_compose_language_service, dockerls }

return M
