vim.filetype.add({
  extension = {
    jinja = 'jinja',
    jinja2 = 'jinja',
    j2 = 'jinja',
  },
})

---@type dotfiles.lsp.Language
return {
  filetypes = { 'jinja' },
  server_tools = { jinja_lsp = { 'jinja-lsp' } },
  tools = { 'jinja-lsp' },
  servers = { jinja_lsp = {} },
}
