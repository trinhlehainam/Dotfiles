describe('Reader session restoration', function()
  it('lazy-loads recovery hooks and restores the source with swap protection', function()
    local root = vim.g.project_settings_test_repo_root
    local plugins = vim.fn.stdpath('data') .. '/lazy'
    local lazy_dir = vim.env.LAZY_DIR or (plugins .. '/lazy.nvim')
    local auto_session_dir = vim.env.AUTO_SESSION_DIR or (plugins .. '/auto-session')
    local reader_dir = vim.env.MARKDOWN_TABLE_WRAP_DIR or (plugins .. '/markdown-table-wrap.nvim')
    for _, dir in ipairs({ lazy_dir, auto_session_dir, reader_dir }) do
      assert.equals(1, vim.fn.isdirectory(dir), 'required plugin missing: ' .. dir)
    end
    local temp = vim.fn.tempname()
    vim.fn.mkdir(temp, 'p')
    local script = temp .. '/check.lua'
    vim.fn.writefile(
      vim.split(
        [=[
local root, lazy_dir, auto_session_dir, reader_dir, temp = unpack(vim.json.decode(vim.env.NVIM_READER_TEST_ARGS))
vim.o.swapfile = true
vim.o.directory = temp .. '/swap//'
vim.opt.sessionoptions = { 'blank', 'buffers', 'curdir', 'tabpages' }
vim.fn.mkdir(temp .. '/swap', 'p')
local source = temp .. '/source.md'
local session = temp .. '/session.vim'
vim.fn.writefile({ '# Reader session test' }, source)
vim.cmd.edit(source)
local source_buf = vim.api.nvim_get_current_buf()
local view = vim.api.nvim_create_buf(false, true)
vim.bo[view].buftype = 'acwrite'
vim.api.nvim_buf_set_name(view, 'markdown-table-wrap://reader/v1/98/' .. vim.uri_encode(source))
vim.api.nvim_set_current_buf(view)
vim.cmd.mksession({ session, bang = true })
vim.api.nvim_buf_delete(view, { force = true })
vim.api.nvim_buf_delete(source_buf, { force = true })

vim.opt.runtimepath:prepend(lazy_dir)
local auto_session = dofile(root .. '/lua/plugins/auto-session.lua')
auto_session.dir = auto_session_dir
auto_session.opts = {
  auto_restore = false,
  auto_save = false,
  root_dir = temp .. '/sessions',
  session_lens = { load_on_setup = false, session_control = { control_dir = temp .. '/control' } },
}
local reader = dofile(root .. '/lua/plugins/markdown-table-wrap.lua')
reader.dir = reader_dir
require('lazy').setup({ auto_session, reader }, {
  root = temp .. '/plugins',
  lockfile = temp .. '/lazy-lock.json',
  state = temp .. '/state.json',
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  readme = { enabled = false },
  pkg = { enabled = false },
  performance = { rtp = { reset = false } },
})

function _G.check_reader_session()
  local plugin = require('lazy.core.config').plugins['markdown-table-wrap.nvim']
  assert(not plugin._.loaded, 'Reader must stay lazy before session restore')
  assert(require('auto-session').restore_session_file(session, { show_message = false }))
  assert(plugin._.loaded, 'SessionLoadPre must load Reader without a Markdown startup file')
  assert(vim.wait(1000, function()
    return vim.api.nvim_buf_get_name(0) == source
  end), 'Reader placeholder must resolve to its source file')
  assert(vim.bo.swapfile, 'Recovered source must retain swap protection')
  assert(vim.deep_equal({ '# Reader session test' }, vim.api.nvim_buf_get_lines(0, 0, -1, false)))
end

]=],
        '\n'
      ),
      script
    )
    local result = vim
      .system({
        vim.v.progpath,
        '--headless',
        '-u',
        script,
        '-i',
        'NONE',
        '-c',
        "lua local ok, err = pcall(check_reader_session); if not ok then io.stderr:write(err); vim.cmd('cquit 1') end",
        '-c',
        'qa!',
      }, {
        text = true,
        cwd = temp,
        env = {
          NVIM_READER_TEST_ARGS = vim.json.encode({
            root,
            lazy_dir,
            auto_session_dir,
            reader_dir,
            temp,
          }),
          XDG_CONFIG_HOME = temp .. '/config',
          XDG_DATA_HOME = temp .. '/data',
          XDG_CACHE_HOME = temp .. '/cache',
          XDG_STATE_HOME = temp .. '/state',
          NVIM_LOG_FILE = temp .. '/nvim.log',
        },
      })
      :wait(10000)
    vim.fn.delete(temp, 'rf')
    assert.equals(0, result.code, result.stdout .. result.stderr)
  end)
end)
