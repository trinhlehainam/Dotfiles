local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' }

-- INFO: https://github.com/ngalaiko/tree-sitter-go-template?tab=readme-ov-file#neovim-integration-using-nvim-treesitter
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

M.formatterconfig.servers = { 'gofumpt', 'goimports-reviser', 'golines' }
M.formatterconfig.formatters_by_ft = {
  go = { 'gofumpt', 'goimports-reviser', 'golines' },
}

-- INFO: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
-- INFO: https://github.com/golang/tools/blob/master/gopls/doc/vim.md#configuration
local gopls = LspConfig:new('gopls', 'gopls')
gopls.config = {
  templateExtensions = { 'tmpl', 'gotmpl' },
}

-- NOTE: golangci-lint-langserver requires golangci-lint to be installed
M.linterconfig.servers = { 'golangci-lint' }
-- INFO: https://github.com/nametake/golangci-lint-langserver?tab=readme-ov-file#configuration-for-nvim-lspconfig
local golangci_lint_ls = LspConfig:new('golangci_lint_ls', 'golangci-lint')

M.lspconfigs = { gopls, golangci_lint_ls }

M.dapconfig.type = 'delve'

M.neotest_adapter_setup = function()
  local has_gotest, gotest = pcall(require, 'neotest-golang')
  if not has_gotest then
    return {}
  end
  return gotest
end

return M
