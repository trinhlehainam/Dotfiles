local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'python' }

-- NOTE: ruff is an running server that watching python files
M.formatterconfig.servers = { 'ruff' }
M.formatterconfig.formatters_by_ft = {
  python = {
    -- "ruff_fix", -- An extremely fast Python linter, written in Rust. Fix lint errors.
    'ruff_format', -- An extremely fast Python linter, written in Rust. Formatter subcommand.
    'ruff_organize_imports', -- An extremely fast Python linter, written in Rust. Organize imports.
  },
}

local pyright = LspConfig:new('pyright', 'pyright')
pyright.config = {
  settings = {
    pyright = {
      -- Using Ruff's import organizer
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        -- Ignore all files for analysis to exclusively use Ruff for linting
        ignore = { '*' },
      },
    },
  },
}

local ruff = LspConfig:new('ruff', 'ruff')
-- Ruff configuration for Neovim
-- INFO: https://docs.astral.sh/ruff/editors/setup/#neovim
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp_attach_disable_ruff_hover', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client == nil then
      return
    end
    if client.name == 'ruff' then
      -- Disable hover in favor of Pyright
      client.server_capabilities.hoverProvider = false
    end
  end,
  desc = 'LSP: Disable hover capability from Ruff',
})

M.lspconfigs = { pyright, ruff }

M.dapconfig.type = 'python'

M.neotest_adapter_setup = function()
  local has_pytest, pytest = pcall(require, 'neotest-python')
  if not has_pytest then
    return {}
  end
  -- NOTE: When encounter no tests found, just add any Python config file in the root directory
  -- INFO: https://github.com/nvim-neotest/neotest-python/issues/40#issuecomment-1336947205
  -- INFO: https://github.com/nvim-neotest/neotest-python/issues/75#issuecomment-2188820822
  -- INFO: https://github.com/rcasia/neotest-bash/issues/17#issuecomment-2183972514
  return pytest
end

return M
