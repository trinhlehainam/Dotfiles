local utils = require('utils')
local is_wins = utils.IS_WINDOWS

local on_attach = function(_, bufnr)
   local rt = require("rust-tools")
   local nmap = utils.create_nmap(bufnr)

   utils.on_attach(_, bufnr)

   nmap("<Leader>ca", rt.code_action_group.code_action_group, '[C]ode [A]ction Groups')

   -- See `:help K` for why this keymap
   nmap("K", rt.hover_actions.hover_actions, "Hover Actions")
end

local dap_adapter_agrs = function()
   if is_wins then
      return { "--port", "${port}" }
   else
      return { "--liblldb", utils.LIBLLDB_PATH, "--port", "${port}" }
   end
end

return {
   'simrat39/rust-tools.nvim',
   dependencies = {
      'nvim-lua/plenary.nvim',

      'neovim/nvim-lspconfig',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',

      'mfussenegger/nvim-dap',
      'jay-babu/mason-nvim-dap.nvim',
   },
   config = function()
      local rt = require("rust-tools")
      local dap = require('dap')

      require('mason').setup()
      local mason_lspconfig = require 'mason-lspconfig'
      mason_lspconfig.setup {
         ensure_installed = { "rust_analyzer" }
      }

      require('mason-nvim-dap').setup {
         automatic_installation = true,
         -- You'll need to check that you have the required things installed
         -- online, please don't ask me how to install them :)
         ensure_installed = {
            -- Update this to ensure that you have the debuggers for the langs you want
            'codelldb',
         },
      }

      dap.configurations.rust = {
         {
            name = "Launch file",
            type = "codelldb",
            request = "launch",
            program = function()
               return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
            end,
            cwd = '${workspaceFolder}',
            stopOnEntry = false,
         },
      }

      mason_lspconfig.setup_handlers {
         function(server_name)
            if server_name == "rust_analyzer" then
               rt.setup({
                  tools = {
                     inlay_hints = {
                        auto = false
                     },
                  },
                  -- see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#rust_analyzer
                  server = {
                     settings = {
                        ["rust-analyzer"] = {
                           checkOnSave = {
                              command = "clippy",
                           },
                        },
                     },
                     on_attach = on_attach,
                     cmd = { utils.RUST_ANALYZER_CMD, },
                  },
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
               })

               rt.inlay_hints.disable()
            end
         end
      }
   end
}
