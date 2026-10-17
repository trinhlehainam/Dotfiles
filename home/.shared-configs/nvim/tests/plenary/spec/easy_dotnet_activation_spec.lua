describe('Easy Dotnet activation', function()
  local function check_bootstrap(kind, startup)
    local root = vim.g.project_settings_test_repo_root
    local plugins = vim.fn.stdpath('data') .. '/lazy'
    local lazy_dir = vim.env.LAZY_DIR or (plugins .. '/lazy.nvim')
    local dotnet_dir = vim.env.EASY_DOTNET_DIR or (plugins .. '/easy-dotnet.nvim')
    local temp = vim.fn.tempname()
    vim.fn.mkdir(temp, 'p')
    local script = temp .. '/check.lua'
    vim.fn.writefile(
      vim.split(
        [=[
local root, lazy_dir, dotnet_dir, temp, kind, startup =
  unpack(vim.json.decode(vim.env.NVIM_DOTNET_TEST_ARGS))
vim.go.loadplugins = true
vim.opt.runtimepath:prepend(lazy_dir)
local spec = dofile(root .. '/lua/plugins/easy-dotnet.lua')
spec.dir = dotnet_dir
spec.dependencies = nil
spec.config = function()
  require('easy-dotnet.cs-mappings').auto_bootstrap_namespace('file_scoped')
end
require('lazy').setup({ spec }, {
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
if kind == 'existing' then
  vim.fn.writefile({}, temp .. '/First.cs')
  vim.fn.writefile({}, temp .. '/Second.cs')
elseif kind == 'unrelated' then
  vim.fn.writefile({}, temp .. '/notes.txt')
end
function _G.check_dotnet_bootstrap()
  local plugin = require('lazy.core.config').plugins['easy-dotnet.nvim']
  if kind == 'unrelated' then
    assert(not plugin._.loaded, 'unrelated startup files must leave Easy Dotnet lazy')
    return
  end
  if not startup then
    vim.fn.writefile({}, temp .. '/unrelated.txt')
    vim.cmd.edit(temp .. '/unrelated.txt')
    assert(not plugin._.loaded, 'unrelated files must leave Easy Dotnet lazy')
  end
  for _, name in ipairs({ 'First.cs', 'Second.cs' }) do
    if not startup or name ~= 'First.cs' then
      vim.cmd.edit(temp .. '/' .. name)
    end
    if kind == 'new' then
      vim.cmd.write()
    end
    assert(plugin._.loaded, 'C# files must activate Easy Dotnet')
    assert(vim.b.easy_dotnet_bootstrap_namespace_pending, name .. ' missed namespace bootstrapping')
  end
end
]=],
        '\n'
      ),
      script
    )

    local command = {
      vim.v.progpath,
      '--headless',
      '-u',
      script,
      '-i',
      'NONE',
      '-c',
      "lua local ok, err = pcall(check_dotnet_bootstrap); if not ok then io.stderr:write(err); vim.cmd('cquit 1') end",
      '-c',
      'qa!',
    }
    if startup then
      command[#command + 1] = temp .. (kind == 'unrelated' and '/notes.txt' or '/First.cs')
    end
    local result = vim
      .system(command, {
        text = true,
        cwd = temp,
        env = {
          NVIM_DOTNET_TEST_ARGS = vim.json.encode({
            root,
            lazy_dir,
            dotnet_dir,
            temp,
            kind,
            startup or false,
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
  end

  it('registers namespace bootstrapping before reading the first C# file', function()
    check_bootstrap('existing')
  end)

  it('registers namespace bootstrapping before creating the first C# file', function()
    check_bootstrap('new')
  end)

  it('bootstraps an existing C# file passed on the command line', function()
    check_bootstrap('existing', true)
  end)

  it('bootstraps a new C# file passed on the command line', function()
    check_bootstrap('new', true)
  end)

  it('keeps Easy Dotnet lazy for unrelated startup files', function()
    check_bootstrap('unrelated', true)
  end)
end)
