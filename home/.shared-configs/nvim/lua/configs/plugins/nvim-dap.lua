local dap = require('dap')
local dapui = require('dapui')

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
dapui.setup()

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close

require('nvim-dap-virtual-text').setup({})

vim.api.nvim_set_hl(0, 'DapBreakpoint', { ctermbg = 0, fg = '#993939', bg = '#31353f' })
vim.api.nvim_set_hl(0, 'DapLogPoint', { ctermbg = 0, fg = '#61afef', bg = '#31353f' })
vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 0, fg = '#98c379', bg = '#31353f' })

vim.fn.sign_define(
  'DapBreakpoint',
  { text = '🔴', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' }
)
vim.fn.sign_define(
  'DapBreakpointCondition',
  { text = '🔴', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' }
)
vim.fn.sign_define(
  'DapBreakpointRejected',
  { text = '', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' }
)
vim.fn.sign_define(
  'DapLogPoint',
  { text = '', texthl = 'DapLogPoint', linehl = 'DapLogPoint', numhl = 'DapLogPoint' }
)
vim.fn.sign_define(
  'DapStopped',
  { text = '', texthl = 'DapStopped', linehl = 'DapStopped', numhl = 'DapStopped' }
)

local adapters = require('configs.lsp').dap
local mason_dap = require('mason-nvim-dap')
mason_dap.setup({
  ensure_installed = adapters,
  automatic_installation = false,
  handlers = {
    function(config)
      -- Mason calls this for every installed adapter. Rust and C# plugins own theirs.
      if vim.tbl_contains(adapters, config.name) then
        mason_dap.default_setup(config)
      end
    end,
  },
})
