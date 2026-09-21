vim.filetype.add({
  extension = {
    gotmpl = 'gotmpl',
    tmpl = 'gotmpl',
  },
})

-- INFO: https://github.com/nvim-treesitter/nvim-treesitter/discussions/1917#discussioncomment-10714144
vim.treesitter.query.add_directive('inject-go-tmpl!', function(_, _, bufnr, _, metadata)
  local fname = vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
  local _, _, ext, _ = string.find(fname, '.*%.(%a+)(%.%a+)')
  metadata['injection.language'] = ext
end, {})

---@type dotfiles.lsp.Language
return {
  parsers = { 'go', 'gomod', 'gowork', 'gotmpl' },
  tools = {
    'gopls',
    'golangci-lint-langserver',
    'golangci-lint',
    'gofumpt',
    'goimports-reviser',
    'golines',
  },
  servers = {
    gopls = {
      settings = {
        gopls = {
          templateExtensions = { 'tmpl', 'gotmpl' },
        },
      },
    },
    golangci_lint_ls = {},
  },
  formatters = { go = { 'gofumpt', 'goimports-reviser', 'golines' } },
  dap = { 'delve' },
  neotest = function()
    return require('neotest-golang')
  end,
}
