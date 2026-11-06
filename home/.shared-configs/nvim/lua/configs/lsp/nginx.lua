---@type dotfiles.lsp.Language
return {
  filetypes = { 'nginx' },
  server_tools = { nginx_language_server = { 'nginx-language-server' } },
  tools = { 'nginx-language-server' },
  servers = { nginx_language_server = {} },
}
