describe('session buffer restoration', function()
  local reader_uri = 'markdown-table-wrap://reader/v1/98/%2Ftmp%2Fsession-test.md'
  local auto_session_dir = vim.env.AUTO_SESSION_DIR
    or (vim.fn.stdpath('data') .. '/lazy/auto-session')
  assert(vim.fn.isdirectory(auto_session_dir) == 1, 'auto-session missing; set AUTO_SESSION_DIR')
  local original
  local root
  local source
  local session

  local function restore_session()
    local auto_session = require('auto-session')
    auto_session.setup({
      auto_restore = false,
      root_dir = root .. '/sessions',
      session_lens = {
        load_on_setup = false,
        session_control = { control_dir = root .. '/control' },
      },
    })
    return auto_session.restore_session_file(session, { show_message = false })
  end

  local function save_session(with_reader)
    vim.cmd.edit(source)
    local source_buf = vim.api.nvim_get_current_buf()
    local reader_buf
    if with_reader then
      reader_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[reader_buf].buftype = 'acwrite'
      vim.bo[reader_buf].swapfile = false
      vim.api.nvim_buf_set_name(reader_buf, reader_uri)
      vim.api.nvim_set_current_buf(reader_buf)
    end
    vim.cmd.mksession({ session, bang = true })
    if reader_buf then
      vim.api.nvim_buf_delete(reader_buf, { force = true })
    end
    vim.api.nvim_buf_delete(source_buf, { force = true })
  end

  local function leave_swap(name)
    local script = string.format(
      [[
vim.o.directory = %q
vim.cmd.file(vim.fn.fnameescape(%q))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved text' })
vim.cmd('silent preserve')
-- Bypass Neovim's normal shutdown so the swap survives for the restore test.
os.exit(0)
]],
      root .. '/swap//',
      name
    )
    local result = vim
      .system({
        vim.v.progpath,
        '--headless',
        '--clean',
        '-i',
        'NONE',
        '-c',
        'lua ' .. script,
      }, { text = true, env = { NVIM_LOG_FILE = root .. '/nvim.log' } })
      :wait(10000)
    assert.equals(0, result.code, result.stderr)
    local swaps = vim.fn.glob(root .. '/swap/*', false, true)
    assert.equals(1, #swaps)
    return swaps[1]
  end

  before_each(function()
    original = {
      directory = vim.o.directory,
      swapfile = vim.go.swapfile,
      updatecount = vim.o.updatecount,
      sessionoptions = vim.o.sessionoptions,
      this_session = vim.v.this_session,
      session_load = vim.g.SessionLoad,
      errmsg = vim.v.errmsg,
      runtimepath = vim.o.runtimepath,
      buffers = {},
    }
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      original.buffers[buf] = true
    end
    root = vim.fn.tempname()
    vim.fn.mkdir(root .. '/swap', 'p')
    source = root .. '/source.md'
    session = root .. '/session.vim'
    vim.fn.writefile({ '# Session test' }, source)
    vim.o.directory = root .. '/swap//'
    vim.o.swapfile = true
    vim.o.updatecount = 200
    vim.opt.sessionoptions = { 'blank', 'buffers', 'curdir', 'tabpages' }
    vim.opt.runtimepath:prepend(auto_session_dir)
    local plugin = require('plugins.auto-session')
    if plugin.init then
      plugin.init()
    end
  end)

  after_each(function()
    if package.loaded['auto-session.config'] then
      require('auto-session.config').auto_save = false
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if not original.buffers[buf] then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    pcall(vim.api.nvim_del_augroup_by_name, 'auto-session-placeholders')
    vim.o.directory = original.directory
    vim.o.swapfile = original.swapfile
    vim.o.updatecount = original.updatecount
    vim.o.sessionoptions = original.sessionoptions
    vim.v.this_session = original.this_session
    vim.g.SessionLoad = original.session_load
    vim.v.errmsg = original.errmsg
    vim.o.runtimepath = original.runtimepath
    vim.fn.delete(root, 'rf')
  end)

  it('restores reader placeholders without opening or deleting their stale swap', function()
    save_session(true)
    local stale_swap = leave_swap(reader_uri)

    assert.is_true(restore_session())
    assert.is_true(require('auto-session.config').auto_save)
    assert.equals(reader_uri, vim.api.nvim_buf_get_name(0))
    assert.is_false(vim.bo.swapfile)
    assert.equals('', vim.fn.swapname(vim.api.nvim_get_current_buf()))
    assert.same({ stale_swap }, vim.fn.glob(root .. '/swap/*', false, true))
  end)

  it('keeps swap enabled for real files restored by a session', function()
    save_session(false)

    assert.is_true(restore_session())

    assert.equals(source, vim.api.nvim_buf_get_name(0))
    assert.is_true(vim.bo.swapfile)
  end)

  it('still reports stale swap conflicts for real files restored by a session', function()
    save_session(false)
    local stale_swap = leave_swap(source)

    assert.is_false(restore_session())
    assert.is_false(require('auto-session.config').auto_save)
    assert.equals(1, vim.fn.filereadable(stale_swap))
  end)

  it('keeps swap enabled when naming an ordinary buffer outside session restore', function()
    vim.cmd.enew()
    vim.cmd.file(source)

    assert.is_true(vim.bo.swapfile)
  end)

  it('keeps swap enabled when a named buffer is renamed during restore', function()
    local renamed = root .. '/renamed.md'
    vim.fn.writefile({
      'edit ' .. vim.fn.fnameescape(source),
      'file ' .. vim.fn.fnameescape(renamed),
    }, session)

    assert.is_true(restore_session())
    assert.equals(renamed, vim.api.nvim_buf_get_name(0))
    assert.is_true(vim.bo.swapfile)
  end)

  it('keeps recovery enabled after a failed restore leaves SessionLoad set', function()
    vim.fn.writefile({
      'let SessionLoad = 1',
      "throw 'session test failure'",
      'unlet SessionLoad',
    }, session)
    assert.is_false(restore_session())
    assert.equals(1, vim.g.SessionLoad)

    vim.cmd.enew()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved user text' })

    vim.cmd.file(root .. '/manual.md')
    assert.is_true(vim.bo.swapfile)
    vim.cmd('silent preserve')
    local swap = vim.fn.swapname(vim.api.nvim_get_current_buf())
    assert.is_not.equals('', swap)
    assert.equals(1, vim.fn.filereadable(swap))
  end)
end)
