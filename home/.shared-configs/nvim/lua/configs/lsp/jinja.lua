vim.filetype.add({
  extension = {
    jinja = 'jinja',
    jinja2 = 'jinja',
    j2 = 'jinja',
  },
})

---@type dotfiles.lsp.Language
return {
  tools = { 'jinja-lsp' },
  servers = { jinja_lsp = {} },
}
