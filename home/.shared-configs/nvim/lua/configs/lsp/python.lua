---@type dotfiles.lsp.Language
return {
  parsers = { 'python' },
  tools = { 'pyright', 'ruff' },
  servers = {
    pyright = {
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
    },
    ruff = {
      on_attach = function(client)
        -- Pyright provides hover; Ruff provides linting and import organization.
        client.server_capabilities.hoverProvider = false
      end,
    },
  },
  formatters = { python = { 'ruff_format', 'ruff_organize_imports' } },
  dap = { 'python' },
  neotest = function()
    return require('neotest-python')
  end,
}
