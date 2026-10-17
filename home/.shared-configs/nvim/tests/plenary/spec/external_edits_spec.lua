describe('Reviewing external agent edits', function()
  local path
  local reference
  local reference_calls
  local notice
  local original_herdr
  local original_notify

  local function write_external(lines)
    local mtime = vim.uv.fs_stat(path).mtime.sec + 1
    vim.fn.writefile(lines, path)
    -- Make the timestamp change deterministic even on fast consecutive writes.
    assert(vim.uv.fs_utime(path, mtime, mtime))
  end

  before_each(function()
    require('configs.options')
    vim.o.undofile = false
    path = vim.fn.tempname()
    vim.fn.writefile({ 'original' }, path)
    vim.cmd.edit(path)
    reference_calls = 0
    notice = nil
    original_herdr = package.loaded['herdr-context']
    original_notify = vim.notify
    package.loaded['herdr-context'] = {
      reference = function()
        reference_calls = reference_calls + 1
      end,
    }
    vim.notify = function(message)
      notice = message
    end
    for _, key in ipairs(require('plugins.herdr-context').keys) do
      if key[1] == '<leader>ay' then
        reference = key[2]
      end
    end
  end)

  after_each(function()
    package.loaded['herdr-context'] = original_herdr
    vim.notify = original_notify
    vim.cmd('bwipeout!')
    vim.fn.delete(path)
  end)

  it('reloads a clean buffer on focus without requiring an agent plugin', function()
    write_external({ 'changed by the agent' })
    vim.api.nvim_exec_autocmds('FocusGained', {})

    assert.same({ 'changed by the agent' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.is_false(vim.bo.modified)
  end)

  it('preserves unsaved editor changes when the agent changes the file', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'my unsaved edit' })
    write_external({ 'changed by the agent' })
    reference()
    vim.api.nvim_exec_autocmds('FocusGained', {})
    vim.api.nvim_exec_autocmds('BufEnter', { buffer = 0 })

    assert.same({ 'my unsaved edit' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.is_true(vim.bo.modified)
    assert.same({ 'changed by the agent' }, vim.fn.readfile(path))
    assert.equals(0, reference_calls)
  end)

  it('refreshes and refuses a stale reference until the user reviews it again', function()
    write_external({ 'inserted by the agent', 'original' })
    assert.same({ 'original' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    reference()

    assert.equals(0, reference_calls)
    assert.same(
      { 'inserted by the agent', 'original' },
      vim.api.nvim_buf_get_lines(0, 0, -1, false)
    )
    assert.matches('File changed on disk', notice)

    reference()
    assert.equals(1, reference_calls)
  end)
end)
