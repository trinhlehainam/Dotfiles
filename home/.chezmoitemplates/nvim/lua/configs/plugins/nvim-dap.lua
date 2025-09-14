local dap = require('dap')
local dapui = require('dapui')

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
end, { desc = '[D]ebug: Terminate and clear breakpoints' })

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
dapui.setup()

-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
vim.keymap.set('n', '<F7>', dapui.toggle, { desc = 'Debug: See last session result.' })

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

local dapconfigs = require('configs.lsp').dapconfigs

--- @type string[]
local daptypes = {}

--- @type table<function>
local setup_handlers = {}

for _, dapconfig in ipairs(dapconfigs) do
  local daptype = dapconfig.type
  if type(daptype) ~= 'string' or daptype == '' then
    goto continue
  end
  table.insert(daptypes, daptype)

  -- https://github.com/jay-babu/mason-nvim-dap.nvim?tab=readme-ov-file#handlers-usage-automatic-setup
  ---@class custom.HandlerConfig
  ---@field name boolean -- adapter name
  ---
  ---	-- All the items below are looked up by the adapter name.
  ---@field adapters table -- https://github.com/jay-babu/mason-nvim-dap.nvim/blob/main/lua/mason-nvim-dap/mappings/adapters
  ---@field configurations table -- https://github.com/jay-babu/mason-nvim-dap.nvim/blob/main/lua/mason-nvim-dap/mappings/configurations.lua
  ---@field filetype string -- https://github.com/jay-babu/mason-nvim-dap.nvim/blob/main/lua/mason-nvim-dap/mappings/filetypes.lua

  ---@param config custom.HandlerConfig
  setup_handlers[dapconfig.type] = function(config)
    if type(dapconfig.setup) == 'function' then
      dapconfig.setup()
    end

    if dapconfig.use_masondap_default_setup then
      require('mason-nvim-dap').default_setup(config)
    end
  end

  ::continue::
end

require('mason-nvim-dap').setup({
  -- A list of adapters to install if they're not already installed.
  -- This setting has no relation with the `automatic_installation` setting.
  ensure_installed = daptypes,

  -- NOTE: this is left here for future porting in case needed
  -- Whether adapters that are set up (via dap) should be automatically installed if they're not already installed.
  -- This setting has no relation with the `ensure_installed` setting.
  -- Can either be:
  --   - false: Daps are not automatically installed.
  --   - true: All adapters set up via dap are automatically installed.
  --   - { exclude: string[] }: All adapters set up via mason-nvim-dap, except the ones provided in the list, are automatically installed.
  --       Example: automatic_installation = { exclude = { "python", "delve" } }
  automatic_installation = false,

  -- INFO: https://github.com/jay-babu/mason-nvim-dap.nvim?tab=readme-ov-file#handlers-usage-automatic-setup
  handlers = setup_handlers,
})
