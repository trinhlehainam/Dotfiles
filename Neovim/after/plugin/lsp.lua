-- IMPORTANT: make sure to setup neodev BEFORE lspconfig
require("neodev").setup({
  -- add any options here, or leave empty to use the default settings
})

local utils = require('utils')

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
-- Prefer Telescope Diagnostic
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

vim.diagnostic.config({
  virtual_text = false,
})

-- Putting vim lsp settings inside on_attach is no longer a best pratice
-- Instead use `LspAttach` event in an autocmd
-- See https://vinnymeller.com/posts/neovim_nightly_inlay_hints/#rust-toolsnvim-inlay-hints
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.inlayHintProvider then
      vim.keymap.set("n", "th",
        function()
          vim.lsp.inlay_hint(args.buf)
        end,
        { buffer = args.buf, desc = "Toggle inlay hints" })
    end
    -- whatever other lsp config you want
  end
})

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
--  See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local servers = {
  -- clangd = {},
  -- gopls = {},
  -- pyright = {},
  -- rust_analyzer = {},
  -- tsserver = {},

  lua_ls = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
}

local langs = require('lsp')
for _, lang in ipairs(langs) do
  servers[lang.lang_server] = {}
end

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Setup mason so it can manage external tooling
require('mason').setup()

-- Ensure the servers above are installed
local mason_lspconfig = require 'mason-lspconfig'

mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}

mason_lspconfig.setup_handlers {
  function(server_name)
    if langs and vim.tbl_contains(vim.tbl_keys(langs), server_name) then
      langs[server_name].lspconfig()
    else
      require('lspconfig')[server_name].setup {
        capabilities = capabilities,
        on_attach = utils.on_attach,
        settings = servers[server_name],
      }
    end
  end,
}

-- Custom lspconfig because Mason hasn't supports these language server yet
local lspconfig = require('lspconfig')

lspconfig.ccls.setup {
  capabilities = capabilities,
  on_attach = utils.on_attach,
}

-- Language server for Postgres written in Rust
-- NOTE: This frame is not production ready yet, check back later
-- lspconfig.postgres_lsp.setup{}
--
