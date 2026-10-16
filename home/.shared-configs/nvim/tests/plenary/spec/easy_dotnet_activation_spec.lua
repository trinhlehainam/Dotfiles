describe('Easy Dotnet activation', function()
  it('registers namespace bootstrapping before reading the first C# file', function()
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
local root, lazy_dir, dotnet_dir, temp = unpack(arg)
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
local plugin = require('lazy.core.config').plugins['easy-dotnet.nvim']
vim.fn.writefile({}, temp .. '/unrelated.txt')
vim.cmd.edit(temp .. '/unrelated.txt')
assert(not plugin._.loaded, 'unrelated files must leave Easy Dotnet lazy')
for _, name in ipairs({ 'First.cs', 'Second.cs' }) do
  vim.fn.writefile({}, temp .. '/' .. name)
  vim.cmd.edit(temp .. '/' .. name)
  assert(plugin._.loaded, 'C# files must activate Easy Dotnet')
  assert(vim.b.easy_dotnet_bootstrap_namespace_pending, name .. ' missed namespace bootstrapping')
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
      'NONE',
      '-i',
      'NONE',
      '-l',
      script,
      root,
      lazy_dir,
      dotnet_dir,
      temp,
    }
    local result = vim
      .system(command, {
        text = true,
        env = {
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
