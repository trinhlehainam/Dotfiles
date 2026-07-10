local M = {}

--- Opens a path-variant picker and copies the selected value to the system clipboard.
--- @source https://neovim.io/doc/user/lua.html#vim.ui.select()
--- @source https://neovim.io/doc/user/provider.html#provider-clipboard
---@param filepath? string
function M.select(filepath)
  if not filepath or filepath == '' then
    vim.notify('No file path available.', vim.log.levels.WARN)
    return
  end

  if vim.fn.has('clipboard') == 0 then
    vim.notify('System clipboard is not available.', vim.log.levels.ERROR)
    return
  end

  local filename = vim.fs.basename(filepath)
  local modify = vim.fn.fnamemodify
  local choices = {
    { label = 'Absolute path', value = filepath },
    { label = 'Path relative to CWD', value = modify(filepath, ':.') },
    { label = 'Path relative to HOME', value = modify(filepath, ':~') },
    { label = 'Filename', value = filename },
    { label = 'Filename without extension', value = modify(filename, ':r') },
    { label = 'Extension of the filename', value = modify(filename, ':e') },
  }

  vim.ui.select(choices, {
    prompt = 'Choose to copy to clipboard:',
    format_item = function(item)
      return string.format('%-30s %s', item.label, item.value)
    end,
  }, function(choice)
    if not choice then
      vim.notify('Copy cancelled.', vim.log.levels.INFO)
      return
    end

    vim.fn.setreg('+', choice.value)
    vim.notify('Copied to clipboard: ' .. choice.value)
  end)
end

return M
