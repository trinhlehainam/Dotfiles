vim.filetype.add({
  extension = {
    conf = 'conf',
    env = 'dotenv',
  },
  filename = {
    ['.env'] = 'dotenv',
  },
  pattern = {
    ['%.env%.[%w_.-]+'] = 'dotenv',
  },
})

---@type dotfiles.lsp.Language
return {
  parsers = { 'bash' },
  tools = { 'bash-language-server', 'shellharden', 'shellcheck' },
  servers = { bashls = {} },
  formatters = { bash = { 'shellharden' }, sh = { 'shellharden' } },
  linters = { bash = { 'shellcheck' }, sh = { 'shellcheck' } },
}
