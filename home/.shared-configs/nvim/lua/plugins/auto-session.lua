-- https://github.com/rmagatti/auto-session
return {
  'rmagatti/auto-session',
  lazy = false,
  init = function()
    -- :mksession names special-buffer placeholders with :file before restoring their options.
    -- BufFilePre still sees an empty name, so matching a Reader URI here cannot work.
    -- Use auto-session's flag: a failed script can leave g:SessionLoad set.
    -- This is internal plugin state; see doc/session-restoration.md for upgrade checks.
    vim.api.nvim_create_autocmd('BufFilePre', {
      group = vim.api.nvim_create_augroup('auto-session-placeholders', { clear = true }),
      callback = function(event)
        local restoring = require('auto-session').restore_in_progress
        if restoring and vim.api.nvim_buf_get_name(event.buf) == '' then
          vim.bo[event.buf].swapfile = false
        end
      end,
    })
  end,
  keys = {
    { '<leader>wr', '<cmd>AutoSession search<CR>', desc = 'Session: search' },
    { '<leader>ws', '<cmd>AutoSession save<CR>', desc = 'Session: save' },
    { '<leader>wa', '<cmd>AutoSession toggle<CR>', desc = 'Session: Toggle autosave' },
  },

  ---enables autocomplete for opts
  ---@module "auto-session"
  ---@type AutoSession.Config
  opts = {
    suppressed_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
    -- The following are already the default values, no need to provide them if these are already the settings you want.
    session_lens = {
      picker = 'snacks', -- "telescope"|"snacks"|"fzf"|"select"|nil Pickers are detected automatically but you can also manually choose one. Falls back to vim.ui.select
      mappings = {
        -- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
        delete_session = { 'i', '<C-d>' },
        alternate_session = { 'i', '<C-s>' },
        copy_session = { 'i', '<C-y>' },
      },

      picker_opts = {
        -- For Snacks, you can set layout options here, see:
        -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-layouts
        --
        -- preset = "dropdown",
        -- preview = false,
        -- layout = {
        --   width = 0.4,
        --   height = 0.4,
        -- },
      },
    },
  },
}
