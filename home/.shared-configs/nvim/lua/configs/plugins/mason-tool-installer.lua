require('mason-tool-installer').setup({
  ensure_installed = require('configs.lsp').tools,
  -- The registry already uses Mason package names; no adapter translation is needed.
  integrations = {
    ['mason-lspconfig'] = false,
    ['mason-null-ls'] = false,
    ['mason-nvim-dap'] = false,
  },
})
