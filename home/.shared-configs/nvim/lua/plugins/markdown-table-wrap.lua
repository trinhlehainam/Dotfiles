-- https://github.com/ice345/markdown-table-wrap.nvim
return {
  'ice345/markdown-table-wrap.nvim',
  -- Register Reader restore hooks even when no Markdown file is opened directly.
  event = 'SessionLoadPre',
  ft = 'markdown',
  opts = {},
}
