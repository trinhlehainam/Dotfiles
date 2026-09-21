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
  tools = { 'docker-compose-language-service', 'dockerfile-language-server' },
  servers = { docker_compose_language_service = {}, dockerls = {} },
}
