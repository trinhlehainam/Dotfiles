-- create code images
return {
  'michaelrommel/nvim-silicon',
  lazy = true,
  -- INFO: https://github.com/michaelrommel/nvim-silicon?tab=readme-ov-file#setup
  opts = {
    -- disable_defaults will disable all builtin default settings apart
    -- from the base arguments, that are needed to call silicon at all, see
    -- mandatory_options below, also those options can be overridden
    -- all of the settings could be overridden in the lua setup call,
    -- but this clashes with the use of an external silicon --config=file,
    -- see issue #9
    disable_defaults = false,

    -- here a function is used to get the name of the current buffer
    window_title = function()
      return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), ':t')
    end,

    -- how to deal with the clipboard on WSL2
    -- possible values are: never, always, auto
    wslclipboard = 'auto',
    -- what to do with the temporary screenshot image file when using the Windows
    -- clipboard from WSL2, possible values are: keep, delete
    wslclipboardcopy = 'delete',
  },
}
