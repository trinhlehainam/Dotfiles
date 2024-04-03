return {
  'mrcjkb/rustaceanvim',
  version = '^4', -- Recommended
  ft = { 'rust' },
  config = function()
    local utils = require('utils')

    local function dap_adapter_agrs()
      if utils.IS_WINDOWS then
        return { "--port", "${port}" }
      else
        return { "--liblldb", utils.LIBLLDB_PATH, "--port", "${port}" }
      end
    end

    vim.g.rustaceanvim = {
      -- Plugin configuration
      tools = {
        inlay_hints = {
          auto = false
        },
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
        on_attach = function (_, bufnr)
          require('lsp.utils').on_attach(_, bufnr)

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
            args = dap_adapter_agrs(),
          },
        }
      },
    }
  end
}
