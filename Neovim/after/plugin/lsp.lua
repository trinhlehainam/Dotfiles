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
  lua_ls = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
}

local langs = require('lsp')
local lang_servers = {}
for _, lang_config in pairs(langs) do
  servers[lang_config.lang_server] = {}
  lang_servers[lang_config.lang_server] = {
    lspconfig = lang_config.lspconfig
  }
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

local lspconfig = require('lspconfig')
local lang_server_names = vim.tbl_keys(lang_servers)

mason_lspconfig.setup_handlers {
  function(server_name)
    if lang_servers and vim.tbl_contains(lang_server_names, server_name) and lang_servers[server_name].lspconfig then
      lang_servers[server_name].lspconfig()
    else
      lspconfig[server_name].setup {
        capabilities = capabilities,
        on_attach = utils.on_attach,
        settings = servers[server_name],
      }
    end
  end,
}

-- Language server for Postgres written in Rust
-- NOTE: This frame is not production ready yet, check back later
-- lspconfig.postgres_lsp.setup{}
--
