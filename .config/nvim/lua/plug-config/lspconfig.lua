local lspconfig = require('lspconfig')

local M = {}

local function ResetDiagnosticDisplay(config)
    local clients = vim.lsp.get_active_clients()
    for client_id,_ in pairs(clients) do
        local buffers = vim.lsp.get_buffers_by_client_id(client_id)
        for _, buffer_id in ipairs(buffers) do
            vim.lsp.diagnostic.display(nil, buffer_id, client_id, config)
        end
    end
end

local function ChangeDiagnosticConfig(config)
    vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
        vim.lsp.diagnostic.on_publish_diagnostics, config
    )
end

ChangeDiagnosticConfig({virtual_text = false})

M.show_virtual_text = true
M.ToggleVirtualText = function()
    M.show_virtual_text = not M.show_virtual_text or false
    local conf = { virtual_text = M.show_virtual_text }
    ChangeDiagnosticConfig(conf)
    ResetDiagnosticDisplay(conf)
end

-- Enable snippetSuport
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { 'pylsp', 'bashls', 'html', 'sumneko_lua' }
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    }
  }
end

-- set the path to the sumneko installation; if you previously installed via the now deprecated :LspInstall, use
local system_name
if vim.fn.has("mac") == 1 then
  system_name = "macOS"
elseif vim.fn.has("unix") == 1 then
  system_name = "Linux"
elseif vim.fn.has('win32') == 1 then
  system_name = "Windows"
else
  print("Unsupported system for sumneko")
end

-- WARNING: HARDCODED PATH
local home = vim.fn.expand('$HOME')
local sumneko_root_path = home..'/lua-language-server'
local sumneko_binary = home..'/lua-language-server/bin/'..system_name..'/lua-language-server'
---------------------------

local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")

require'lspconfig'.sumneko_lua.setup {
  cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"};
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
        -- Setup your lua path
        path = runtime_path
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

local keymap = vim.api.nvim_set_keymap
local opts = {silent = true, noremap = true}
keymap('n','te',":lua require'plug-config.lspconfig'.ToggleVirtualText()<CR>",opts)

return M
