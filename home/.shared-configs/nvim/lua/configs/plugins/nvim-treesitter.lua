local treesitter = require('nvim-treesitter')

local ensure_installed = {
  -- #region Required
  -- A list of parser names, or "all" (the five listed parsers should always be installed)
  'c',
  'lua',
  'vim',
  'vimdoc',
  'query',
  'markdown',
  'markdown_inline',
  -- #endregion Required

  'dockerfile',
  'sql',
}

local has_noiceconfig, noiceconfig = pcall(require, 'configs.plugins.noice')
if has_noiceconfig and vim.islist(noiceconfig.parsers) then
  ensure_installed = vim.list_extend(ensure_installed, require('configs.plugins.noice').parsers)
end

local treesitters = require('configs.lsp').treesitters

for _, config in ipairs(treesitters) do
  local filetypes = config.filetypes
  if filetypes ~= nil and vim.islist(filetypes) then
    vim.list_extend(ensure_installed, filetypes)
  end
end

-- Check :h nvim-treesitter-commands for a list of all available commands.
treesitter.install(ensure_installed)

vim.api.nvim_create_autocmd('FileType', {
  pattern = ensure_installed,
  callback = function()
    vim.treesitter.start()
  end,
})
