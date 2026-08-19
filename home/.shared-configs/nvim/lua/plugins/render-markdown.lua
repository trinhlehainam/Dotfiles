-- https://github.com/MeanderingProgrammer/render-markdown.nvim
return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    preset = 'obsidian',
    -- https://github.com/MeanderingProgrammer/render-markdown.nvim?tab=readme-ov-file#completions
    completions = { lsp = { enabled = true } },
    pipe_table = { enabled = false }, -- handled by markdown-table-wrap.nvim
    win_options = {
      wrap = { default = vim.o.wrap, rendered = true },
      linebreak = { default = vim.o.linebreak, rendered = true },
    },
    code = {
      sign = false,
    },
  },
  init = function()
    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'markdown' },
      callback = function()
        vim.treesitter.start()
      end,
    })
  end,
}
