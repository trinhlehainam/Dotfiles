-- NOTE: Tutorial:
-- https://www.youtube.com/watch?v=ALGBuFLzDSA

-- NOTE: Connection over ssh:
-- https://github.com/tpope/vim-dadbod/issues/9

-- NOTE: Connection with URLS
-- :help dadbod-urls
-- params use in url (username, password, etc): must be an URL escaped string

-- NOTE: Genreate urlenconded string in shell
-- https://stackoverflow.com/a/34407620
-- use `printf %s "$string" | jq -sRr @uri` command to convert a normal string to URL escaped string

return {
  'kristijanhusak/vim-dadbod-ui',
  dependencies = {
    { 'tpope/vim-dadbod', lazy = true },
    { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    'hrsh7th/nvim-cmp',
  },
  cmd = {
    'DBUI',
    'DBUIToggle',
    'DBUIAddConnection',
    'DBUIFindBuffer',
  },
  init = function()
    -- Your DBUI configuration
    vim.g.db_ui_use_nerd_fonts = 1

    require('cmp').setup.filetype({ 'sql', 'mysql', 'plsql' }, {
      sources = {
        { name = 'vim-dadbod-completion' },
        { name = 'buffer' },
      },
    })
  end,
}
