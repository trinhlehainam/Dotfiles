return { -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  -- Capabilities and shared LspAttach hooks must exist before filetype-owned servers start.
  lazy = false,
  dependencies = {
    'folke/snacks.nvim',
    'mrjones2014/codesettings.nvim',
    -- Roslyn's native config must be on runtimepath before the registry resolves it.
    'seblyng/roslyn.nvim',
    -- Automatically install LSPs and related tools to stdpath for Neovim
    -- Mason must be loaded before its dependents so we need to set it up here.
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    -- https://github.com/mason-org/mason.nvim
    {
      'mason-org/mason.nvim',
      config = function()
        -- Mason's Windows Python workaround is unnecessary for minimal prompt edits.
        -- https://github.com/williamboman/mason.nvim/issues/1753
        if require('utils.common').IS_WINDOWS and vim.fn.executable('pyenv') == 1 then
          local version = vim.fn.system('pyenv global'):gsub('%s+$', '')
          local python_path = vim.env.USERPROFILE .. '/.pyenv/pyenv-win/versions/' .. version
          if vim.v.shell_error == 0 and vim.fn.executable(python_path .. '/python.exe') == 1 then
            vim.env.PATH = python_path .. ';' .. vim.env.PATH
          end
        end
        require('mason').setup({
          -- https://github.com/seblyng/roslyn.nvim?tab=readme-ov-file#-installation
          registries = {
            'github:mason-org/mason-registry',
            'github:Crashdummyy/mason-registry',
          },
        })
      end,
    },
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP
    { 'j-hui/fidget.nvim', opts = {} },

    -- Allows extra capabilities provided by blink.cmp
    'saghen/blink.cmp',
  },
  config = function()
    require('configs.plugins.nvim-lspconfig')
  end,
}
