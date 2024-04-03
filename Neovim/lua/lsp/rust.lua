local Lang = require('lsp.base')
local M = Lang:new()

local utils = require('utils')
local is_wins = utils.IS_WINDOWS

local function dap_adapter_agrs()
  if is_wins then
    return { "--port", "${port}" }
  else
    return { "--liblldb", utils.LIBLLDB_PATH, "--port", "${port}" }
  end
end

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

---@param on_attach fun(_: lsp.Client, bufnr: number)
---@return fun(_: lsp.Client, bufnr: number)
local function create_on_attach(on_attach)
  return function(_, bufnr)
    local rt = require("rust-tools")
    local nmap = utils.create_nmap(bufnr)

    on_attach(_, bufnr)

    nmap("<Leader>ca", rt.code_action_group.code_action_group, '[C]ode [A]ction Groups')

    -- See `:help K` for why this keymap
    nmap("K", rt.hover_actions.hover_actions, "Hover Actions")
  end
end

-- NOTE: rustaceanvim will configure automatically rust-analyzer
M.lang_server = "rust_analyzer"
M.lspconfig.setup = function(_, on_attach)
  local rt = require("rust-tools")
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
      on_attach = create_on_attach(on_attach),
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

return M
