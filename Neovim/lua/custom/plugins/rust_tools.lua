local on_attach = function(_, bufnr)
   local rt = require("rust-tools")

   local nmap = function(keys, func, desc)
      if desc then
         desc = 'LSP: ' .. desc
      end

      vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
   end

   nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
   nmap("<Leader>ca", rt.code_action_group.code_action_group, '[C]ode [A]ction Groups')

   nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
   nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
   nmap('gI', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
   nmap('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
   nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
   nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

   -- See `:help K` for why this keymap
   nmap("K", rt.hover_actions.hover_actions, "Hover Actions")
   nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

   -- Lesser used LSP functionality
   nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
   nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
   nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
   nmap('<leader>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
   end, '[W]orkspace [L]ist Folders')

   -- Create a command `:Format` local to the LSP buffer
   vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
      vim.lsp.buf.format()
   end, { desc = 'Format current buffer with LSP' })
end

local is_windows = _G.IS_WINDOWS;

local mason_path = function()
   if is_windows then
      return vim.env.HOME .. '/AppData/Local/nvim-data/mason/'
   else
      return vim.env.HOME .. '/.local/share/nvim/mason/'
   end
end

local rust_analyzer_cmd = function()
   if is_windows then
      return mason_path() .. 'packages/' .. 'rust-analyzer/rust-analyzer.exe'
   else
      return mason_path() .. 'bin/' .. 'rust-analyzer'
   end
end

local codelldb_exetension_path = function()
   return mason_path() .. 'packages/' .. 'codelldb/extension/'
end

local codelldb_path = function()
   if is_windows then
      return mason_path() .. 'bin/' .. 'codelldb.cmd'
   else
      return codelldb_exetension_path() .. 'adapter/codelldb'
   end
end

local liblldb_path = function()
   if is_windows then
      return ''
   else
      return codelldb_exetension_path() .. 'lldb/lib/liblldb.so'
   end
end

local dap_adapter_agrs = function()
   if is_windows then
      return { "--port", "${port}" }
   else
      return { "--liblldb", liblldb_path(), "--port", "${port}" }
   end
end

return {
   'simrat39/rust-tools.nvim',
   dependencies = {
      'nvim-lua/plenary.nvim',

      'williamboman/mason.nvim',

      'neovim/nvim-lspconfig',
      -- 'williamboman/mason-lspconfig.nvim',

      'mfussenegger/nvim-dap',
      'jay-babu/mason-nvim-dap.nvim',
   },
   config = function()
      local rt = require("rust-tools")
      local dap = require('dap')

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
            cmd = { rust_analyzer_cmd() },
         },
         dap = {
            adapter = {
               type = "server",
               port = "${port}",
               host = "127.0.0.1",
               executable = {
                  command = codelldb_path(),
                  args = dap_adapter_agrs(),
               },
            }
         },
      })

      rt.inlay_hints.disable()
   end
}
