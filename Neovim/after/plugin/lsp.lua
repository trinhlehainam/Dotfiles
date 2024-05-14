if vim.g.vscode then
  return
end

-- IMPORTANT: make sure to setup neodev BEFORE lspconfig
require("neodev").setup({
  -- add any options here, or leave empty to use the default settings
})

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
-- Prefer Telescope Diagnostic
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

vim.diagnostic.config({
  virtual_text = false,
})

-- Custom Diagnostic Signs
local signs = { Error = "", Warn = "", Hint = "", Info = "" }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

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
          vim.lsp.inlay_hint.enable(args.buf, not vim.lsp.inlay_hint.is_enabled(args.buf))
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
  dockerls = {},
  lua_ls = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
      completion = { callSnippet = "Replace" },
    },
  },
}

---@type table<string, custom.Lang>
local langs = require('lsp').langs

---@type fun(capabilities: lsp.ClientCapabilities, on_attach: fun(client: lsp.Client, bufnr: integer))
local on_attach = require('lsp.utils').on_attach

---@class custom.LangServer
---@field setup custom.LspConfig.Setup

---@type table<string, custom.LangServer>
local lang_servers = {}

for _, lang_config in pairs(langs) do
  local server_name = lang_config.lang_server
  if not server_name or server_name == "" then goto continue end
  servers[server_name] = lang_config.lspconfig.settings

  local setup = lang_config.lspconfig.setup
  if not setup then goto continue end
  lang_servers[server_name] = {
    setup = setup
  }

  ::continue::
end

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Setup mason so it can manage external tooling
require('mason').setup()

-- Ensure the servers above are installed
local mason_lspconfig = require('mason-lspconfig')
mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}

local lspconfig = require('lspconfig')
local lang_server_names = vim.tbl_keys(lang_servers)
mason_lspconfig.setup_handlers {
  function(server_name)
    if lang_servers and vim.tbl_contains(lang_server_names, server_name) then
      lang_servers[server_name].setup(capabilities, on_attach)
    else
      lspconfig[server_name].setup {
        capabilities = capabilities,
        on_attach = on_attach,
        settings = servers[server_name],
      }
    end
  end,
}

-- Language server for Postgres written in Rust
-- NOTE: This framework is not production ready yet, check back later
-- lspconfig.postgres_lsp.setup{}
--
