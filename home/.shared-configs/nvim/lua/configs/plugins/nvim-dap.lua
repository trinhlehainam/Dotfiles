local dap = require('dap')
local dapui = require('dapui')

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
dapui.setup()

-- Basic debugging keymaps, feel free to change to your liking!
vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F10>', dap.step_over, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F11>', dap.step_into, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F12>', dap.step_out, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function()
  dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
end, { desc = 'Debug: Set Breakpoint' })
vim.keymap.set('n', '<leader>do', dap.step_over, { desc = '[D]ebug: Step [o]ver' })
vim.keymap.set('n', '<leader>di', dap.step_into, { desc = '[D]ebug: Step [i]nto' })
vim.keymap.set('n', '<leader>dc', dap.run_to_cursor, { desc = '[D]ebug: Run to [c]ursor' })
vim.keymap.set('n', '<leader>dr', dap.repl.toggle, { desc = '[D]ebug: Toggle DAP [R]EPL' })
vim.keymap.set('n', '<leader>dj', dap.down, { desc = '[D]ebug: Go down stack frame' })
vim.keymap.set('n', '<leader>dk', dap.up, { desc = '[D]ebug: Go up stack frame' })
vim.keymap.set('n', '<leader>ds', dap.terminate, { desc = '[D]ebug: [S]top (terminate)' })
vim.keymap.set('n', '<leader>dq', function()
  dap.terminate()
  dap.clear_breakpoints()
  dapui.close()
end, { desc = '[D]ebug: Terminate and clear breakpoints' })

-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
vim.keymap.set('n', '<leader>dt', dapui.toggle, { desc = 'Debug: See last session result.' })

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
