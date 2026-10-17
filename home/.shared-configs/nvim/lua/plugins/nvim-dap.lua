-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- Rustaceanvim discovers Cargo debug targets asynchronously; load before editing starts.
  ft = 'rust',
  -- Preserve DAP's automatic template when creating a launch configuration.
  event = { { event = 'BufNewFile', pattern = '*/.vscode/launch.json' } },
  cmd = {
    'DapContinue',
    'DapSetLogLevel',
    'DapToggleBreakpoint',
    'DapClearBreakpoints',
    'DapToggleRepl',
    'DapStepOver',
    'DapStepInto',
    'DapStepOut',
    'DapTerminate',
    'DapPause',
    'DapDisconnect',
    'DapRestartFrame',
    'DapNew',
    'DapShowLog',
    'DapEval',
  },
  keys = {
    { '<F5>', '<Cmd>DapContinue<CR>', desc = 'Debug: Start/Continue' },
    { '<F10>', '<Cmd>DapStepOver<CR>', desc = 'Debug: Step Over' },
    { '<F11>', '<Cmd>DapStepInto<CR>', desc = 'Debug: Step Into' },
    { '<F12>', '<Cmd>DapStepOut<CR>', desc = 'Debug: Step Out' },
    { '<leader>b', '<Cmd>DapToggleBreakpoint<CR>', desc = 'Debug: Toggle Breakpoint' },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))
      end,
      desc = 'Debug: Set Breakpoint',
    },
    { '<leader>do', '<Cmd>DapStepOver<CR>', desc = '[D]ebug: Step [o]ver' },
    { '<leader>di', '<Cmd>DapStepInto<CR>', desc = '[D]ebug: Step [i]nto' },
    {
      '<leader>dc',
      function()
        require('dap').run_to_cursor()
      end,
      desc = '[D]ebug: Run to [c]ursor',
    },
    { '<leader>dr', '<Cmd>DapToggleRepl<CR>', desc = '[D]ebug: Toggle DAP [R]EPL' },
    {
      '<leader>dj',
      function()
        require('dap').down()
      end,
      desc = '[D]ebug: Go down stack frame',
    },
    {
      '<leader>dk',
      function()
        require('dap').up()
      end,
      desc = '[D]ebug: Go up stack frame',
    },
    { '<leader>ds', '<Cmd>DapTerminate<CR>', desc = '[D]ebug: [S]top (terminate)' },
    {
      '<leader>dq',
      function()
        local dap = require('dap')
        dap.terminate()
        dap.clear_breakpoints()
        require('dapui').close()
      end,
      desc = '[D]ebug: Terminate and clear breakpoints',
    },
    {
      '<leader>dt',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
  },
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    {
      'rcarriga/nvim-dap-ui',
      dependencies = {
        'nvim-neotest/nvim-nio',
      },
    },

    'theHamsta/nvim-dap-virtual-text',
    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    -- NOTE: nvim-dap-python requires luarocks to be installed for correct build
    -- Install luarocks: https://github.com/luarocks/luarocks/wiki/Download
    'mfussenegger/nvim-dap-python',
    'leoluz/nvim-dap-go',
  },
  config = function()
    require('configs.plugins.nvim-dap')
  end,
}
