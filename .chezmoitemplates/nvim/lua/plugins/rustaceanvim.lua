return {
  'mrcjkb/rustaceanvim',
  version = '^4', -- Recommended
  lazy = false,
  config = function()
    local utils = require('utils')

    vim.g.rustaceanvim = {
      -- Plugin configuration
      tools = {
      },
      -- LSP configuration
      server = {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = {
              command = "clippy",
            },
          },
        },
        on_attach = function(_, bufnr)
          require('configs.lsp.utils').on_attach(_, bufnr)

          local nmap = utils.create_nmap(bufnr)
          local vmap = utils.create_vmap(bufnr)
          nmap("<leader>ca",
            function()
              vim.cmd.RustLsp('codeAction')
            end,
            '[C]ode [A]ction')
          vmap("<leader>ca",
            function()
              vim.cmd.RustLsp('codeAction')
            end,
            '[C]ode [A]ction Groups')
        end,
        cmd = { utils.RUST_ANALYZER_CMD, },
      },
      -- DAP configuration
      dap = {
        adapter = {
          type = "server",
          port = "${port}",
          host = "127.0.0.1",
          executable = {
            command = utils.CODELLDB_PATH,
            args = utils.DAP_ADAPTER_ARGS,
          },
        }
      },
    }
  end
}

