describe('Reviewing external agent edits', function()
  local path

  before_each(function()
    require('configs.options')
    vim.o.undofile = false
    path = vim.fn.tempname()
    vim.fn.writefile({ 'original' }, path)
    vim.cmd.edit(path)
  end)

  after_each(function()
    vim.cmd('bwipeout!')
    vim.fn.delete(path)
  end)

  it('reloads a clean buffer on focus without requiring an agent plugin', function()
    vim.fn.writefile({ 'changed by the agent' }, path)
    vim.api.nvim_exec_autocmds('FocusGained', {})

    assert.same({ 'changed by the agent' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.is_false(vim.bo.modified)
  end)

  it('preserves unsaved editor changes when the agent changes the file', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'my unsaved edit' })
    vim.fn.writefile({ 'changed by the agent' }, path)
    vim.api.nvim_exec_autocmds('FocusGained', {})
    vim.api.nvim_exec_autocmds('BufEnter', { buffer = 0 })

    assert.same({ 'my unsaved edit' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.is_true(vim.bo.modified)
    assert.same({ 'changed by the agent' }, vim.fn.readfile(path))
  end)
end)
