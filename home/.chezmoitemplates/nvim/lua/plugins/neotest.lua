return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',

    -- adapters
    -- INFO: https://github.com/nvim-neotest/neotest?tab=readme-ov-file#supported-runners
    'nvim-neotest/neotest-plenary',
    'mrcjkb/rustaceanvim',
    'nvim-neotest/neotest-python',
    'fredrikaverpil/neotest-golang',
  },
  config = function()
    local adapters = { require('neotest-plenary') }
    vim.list_extend(adapters, require('configs.lsp').get_neotest_adapters())
    require('neotest').setup({
      adapters = adapters,
    })
  end,
}
