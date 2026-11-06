describe('first-use Rust debugging inside neotest tasks', function()
  local saved, original, state, dap, nio, task
  local modules = {
    'mason-registry',
    'mason-core.installer.InstallLocation',
    'utils.mason_install',
    'features.dap_install',
    'mason-nvim-dap.mappings.source',
    'mason-nvim-dap.mappings.filetypes',
    'mason-nvim-dap.mappings.configurations',
  }

  before_each(function()
    original = { runtimepath = vim.o.runtimepath, rust = vim.g.rustaceanvim }
    local plugins = vim.fn.stdpath('data') .. '/lazy'
    for _, path in ipairs({
      vim.env.DAP_DIR or (plugins .. '/nvim-dap'),
      vim.env.NIO_DIR or (plugins .. '/nvim-nio'),
    }) do
      assert.equals(1, vim.fn.isdirectory(path), 'Missing test plugin: ' .. path)
      vim.opt.runtimepath:append(path)
    end
    dap, nio = require('dap'), require('nio')
    original.attach, original.adapter = dap.attach, dap.adapters.codelldb
    original.listeners = vim.deepcopy(dap.listeners.on_config)
    saved = {}
    for _, name in ipairs(modules) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    local registry
    registry, state = require('fake_mason').new()
    package.loaded['mason-registry'] = registry
    package.loaded['mason-core.installer.InstallLocation'] = state.location
    package.loaded['mason-nvim-dap.mappings.source'] = { nvim_dap_to_package = {} }
    package.loaded['mason-nvim-dap.mappings.filetypes'] = {}
    package.loaded['mason-nvim-dap.mappings.configurations'] = {}
    dofile(vim.g.project_settings_test_repo_root .. '/lua/plugins/rustaceanvim.lua').init()
    require('features.dap_install').setup({})
    -- Rustaceanvim fills this only if our wrapper has not registered an adapter.
    dap.adapters.codelldb = dap.adapters.codelldb or vim.g.rustaceanvim.dap.adapter
  end)

  after_each(function()
    if task then
      task.cancel()
    end
    dap.attach, dap.adapters.codelldb = original.attach, original.adapter
    dap.listeners.on_config = original.listeners
    vim.o.runtimepath, vim.g.rustaceanvim = original.runtimepath, original.rust
    state.cleanup()
    for _, name in ipairs(modules) do
      package.loaded[name] = saved[name]
    end
  end)

  it('preserves nio scheduling while waiting for installation and adapter startup', function()
    local started = nio.control.future()
    local result, adapter, launches
    launches = 0
    -- Exercise real dap.run and nio scheduling; replace only the process launch.
    dap.attach = function(resolved, config)
      launches = launches + 1
      adapter = resolved
      assert.equals('Rust test', config.name)
      started.set(true)
    end
    task = nio.run(function()
      nio.scheduler()
      dap.run({ type = 'codelldb', request = 'launch', name = 'Rust test' })
      started.wait()
      nio.sleep(1)
      return 'done'
    end, function(ok, value)
      result = { ok, value }
    end)
    assert.is_true(vim.wait(500, function()
      return #state.refreshes > 0
    end, 1))
    state.refresh()
    assert.is_true(vim.wait(500, function()
      return #state.installs > 0
    end, 1))
    assert.same({ 'codelldb' }, state.installs)
    assert.equals(0, launches)
    assert.is_nil(result)
    state.finish('codelldb', true)
    assert.is_true(vim.wait(500, function()
      return result ~= nil
    end, 1))
    assert.same({ true, 'done' }, result)
    assert.equals(1, launches)
    assert.same(vim.g.rustaceanvim.dap.adapter, adapter)
  end)
end)
