local function reference(whole_file)
  if vim.bo.modified then
    vim.notify(
      'Save before referencing this file, or use <leader>as to stage unsaved lines.',
      vim.log.levels.WARN
    )
    return
  end
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= '' or vim.fn.filereadable(path) ~= 1 or path:find('%c') then
    vim.notify(
      'Herdr references need a saved file with no control characters in its path.',
      vim.log.levels.WARN
    )
    return
  end
  local opts = whole_file and { line1 = 1, line2 = vim.api.nvim_buf_line_count(0) } or nil
  require('herdr-context').reference(opts)
end

return {
  'makyinmars/herdr-context.nvim',
  commit = '2e99ef05c52e1a8ee71b630612a0f8ac18a9638e',
  cond = function()
    return vim.fn.executable('herdr') == 1
  end,
  cmd = { 'HerdrContextReference', 'HerdrContextSend' },
  opts = {
    -- Neovim runs in tmux. Herdr's focused workspace may belong to another editor.
    target_scope = 'session',
    remember_target = 'none',
    auto_select = false,
    submit = false,
    focus_after_send = true,
    -- Keep multiline source out of terminal input; agents read a local context file.
    multiline_strategy = 'context_file',
    -- Separate editors must not generate the same temporary filename in the same second.
    context_file_dir = vim.fn.stdpath('cache') .. '/herdr-context/' .. vim.fn.getpid(),
    presence = { enabled = false },
  },
  keys = {
    {
      '<leader>ab',
      function()
        reference(true)
      end,
      desc = 'Herdr: reference saved file',
    },
    {
      '<leader>ay',
      function()
        reference(false)
      end,
      mode = { 'n', 'x' },
      desc = 'Herdr: reference saved lines',
    },
    { '<leader>as', '<cmd>HerdrContextSend<cr>', desc = 'Herdr: stage current line' },
    -- Ex ranges deliberately send whole lines, including when selecting multibyte text.
    { '<leader>as', ':HerdrContextSend<cr>', mode = 'x', desc = 'Herdr: stage selected lines' },
  },
}
