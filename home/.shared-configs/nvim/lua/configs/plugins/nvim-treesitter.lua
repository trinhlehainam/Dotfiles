local merge_unique = require('utils.common').merge_unique_strings
local parsers = merge_unique({
  'c',
  'lua',
  'vim',
  'vimdoc',
  'query',
  'markdown',
  'markdown_inline',
  'dockerfile',
  'sql',
}, require('configs.lsp').parsers)
parsers = merge_unique(parsers, require('configs.plugins.noice').parsers)

require('nvim-treesitter').install(parsers)

local enabled = {}
for _, parser in ipairs(parsers) do
  enabled[parser] = true
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('dotfiles-treesitter', { clear = true }),
  callback = function(event)
    -- Buffer filetypes can be aliases (sh → bash) or composite (yaml.ansible).
    local parser = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
    if parser and enabled[parser] and vim.treesitter.language.add(parser) then
      vim.treesitter.start(event.buf, parser)
    end
  end,
})
