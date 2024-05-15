local LanguageSetting = require('configs.lsp.base')
local M = LanguageSetting:new()

M.daptype = "codelldb"
M.dapconfig = {
  {
    name = "Launch file",
    type = M.daptype,
    request = "launch",
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  },
}

M.server_name = "rust_analyzer"
M.lspconfig.setup = function(_, _)
  -- NOTE: rustaceanvim will automatically configure rust-analyzer
  -- empty mason "rust-analyzer" setup to avoid conflict with rustaceanvim
end

return M
