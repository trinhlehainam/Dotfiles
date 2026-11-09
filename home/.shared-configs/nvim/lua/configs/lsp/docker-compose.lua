vim.filetype.add({
  filename = {
    ['docker-compose.yml'] = 'yaml.docker-compose',
    ['docker-compose.yaml'] = 'yaml.docker-compose',
    ['compose.yml'] = 'yaml.docker-compose',
    ['compose.yaml'] = 'yaml.docker-compose',
  },
})

---@type dotfiles.lsp.Language
return {
  filetypes = { 'yaml.docker-compose', 'dockerfile' },
  server_tools = {
    docker_compose_language_service = { 'docker-compose-language-service' },
    dockerls = { 'dockerfile-language-server' },
  },
  tools = { 'docker-compose-language-service', 'dockerfile-language-server' },
  servers = { docker_compose_language_service = {}, dockerls = {} },
}
