return {
  -- https://github.com/mrcjkb/rustaceanvim
  'mrcjkb/rustaceanvim',
  dependencies = {
    'neovim/nvim-lspconfig',
  },
  version = '^6', -- Recommended
  lazy = false, -- This plugin is already lazy
  init = function()
    -- Keep Rust test commands using Neotest even before its first lazy load.
    vim.g.rustaceanvim = {
      tools = { test_executor = 'neotest' },
      -- The language installer starts this plugin after rust-analyzer is ready.
      server = { auto_attach = false },
      -- Keep the adapter discoverable before first installation; DAP waits for Mason.
      dap = {
        adapter = {
          type = 'server',
          port = '${port}',
          executable = {
            command = vim.fs.joinpath(
              vim.fn.stdpath('data'),
              'mason',
              'packages',
              'codelldb',
              'extension',
              'adapter',
              'codelldb' .. (require('utils.common').IS_WINDOWS and '.exe' or '')
            ),
            args = { '--port', '${port}' },
            detached = not require('utils.common').IS_WINDOWS,
          },
        },
      },
    }
  end,
}
