local LangBase = require('configs.lsp.base')
local M = LangBase:new()

M.dap_type = "codelldb"
M.dapconfig = {
  {
    name = "Launch file",
    type = M.dap_type,
    request = "launch",
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  },
}

M.lang_server = "rust_analyzer"
M.lspconfig.setup = function(_, _)
  -- NOTE: rustaceanvim will automatically configure rust-analyzer
  -- empty mason "rust-analyzer" setup to avoid conflict with rustaceanvim
end

return M
