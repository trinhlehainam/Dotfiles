describe('debug adapter installation', function()
  local saved, state, dap, resolve, configs, original_rust
  local modules = {
    'dap',
    'mason-registry',
    'mason-core.installer.InstallLocation',
    'utils.mason_install',
    'features.dap_install',
    'mason-nvim-dap.mappings.source',
    'mason-nvim-dap.mappings.filetypes',
    'mason-nvim-dap.mappings.configurations',
    'mason-nvim-dap.mappings.adapters.python',
  }
  local function drain()
    vim.wait(20, function()
      return false
    end, 1)
  end
  before_each(function()
    original_rust = vim.g.rustaceanvim
    dofile(vim.g.project_settings_test_repo_root .. '/lua/plugins/rustaceanvim.lua').init()
    saved = {}
    for _, name in ipairs(modules) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    local registry
    registry, state = require('fake_mason').new()
    package.loaded['mason-registry'] = registry
    package.loaded['mason-core.installer.InstallLocation'] = state.location
    dap = { adapters = { coreclr = { command = 'plugin-owned' } }, configurations = {} }
    configs = { { type = 'python', name = 'Launch', request = 'launch' } }
    package.loaded.dap = dap
    package.loaded['mason-nvim-dap.mappings.source'] =
      { nvim_dap_to_package = { python = 'debugpy' } }
    package.loaded['mason-nvim-dap.mappings.filetypes'] = { python = { 'python' } }
    package.loaded['mason-nvim-dap.mappings.configurations'] = { python = configs }
    package.loaded['mason-nvim-dap.mappings.adapters.python'] =
      { type = 'executable', command = 'debugpy-adapter' }
    require('features.dap_install').setup({ 'python' })
    resolve = dap.adapters.python
  end)
  after_each(function()
    drain()
    state.cleanup()
    vim.g.rustaceanvim = original_rust
    for _, name in ipairs(modules) do
      package.loaded[name] = saved[name]
    end
  end)
  it('provides launch configurations without installing any adapter', function()
    assert.same(configs, dap.configurations.python)
    assert.same({}, state.refreshes)
    assert.same({}, state.installs)
  end)
  it('installs the selected adapter then resumes the original launch', function()
    local result
    resolve(function(adapter)
      result = adapter
    end, configs[1])
    drain()
    state.refresh()
    drain()
    assert.same({ 'debugpy' }, state.installs)
    assert.is_nil(result)
    state.finish('debugpy', true)
    drain()
    assert.equals('debugpy-adapter', result.command)
  end)
  it('resolves installed adapters without refreshing Mason', function()
    state.seed('debugpy')
    local result
    resolve(function(adapter)
      result = adapter
    end, configs[1])
    drain()
    assert.equals('debugpy-adapter', result.command)
    assert.same({}, state.refreshes)
  end)
  it('does not launch after failed installation and supports a manual retry', function()
    local original_notify = vim.notify
    vim.notify = function() end
    local calls = 0
    resolve(function()
      calls = calls + 1
    end, configs[1])
    drain()
    state.refresh()
    drain()
    state.finish('debugpy', false)
    drain()
    assert.equals(0, calls)
    state.finish('debugpy', true)
    drain()
    resolve(function()
      calls = calls + 1
    end, configs[1])
    drain()
    vim.notify = original_notify
    assert.equals(1, calls)
  end)

  it('preserves functional adapter callbacks and the original launch configuration', function()
    state.seed('debugpy')
    package.loaded['mason-nvim-dap.mappings.adapters.python'] = function(callback, config)
      assert.equals(configs[1], config)
      callback({ type = 'server', port = 1234 })
    end
    local result
    resolve(function(adapter)
      result = adapter
    end, configs[1])
    drain()
    assert.equals(1234, result.port)
  end)

  it('explains subsequent debug launches after an install failure', function()
    local original_notify = vim.notify
    local messages = {}
    vim.notify = function(message)
      messages[#messages + 1] = message
    end
    resolve(function()
      error('must not launch')
    end, configs[1])
    drain()
    state.refresh()
    drain()
    state.finish('debugpy', false)
    drain()
    messages = {}
    resolve(function()
      error('must not launch')
    end, configs[1])
    drain()
    vim.notify = original_notify
    assert.equals(1, #messages)
    assert.matches(':MasonInstall debugpy', messages[1], 1, true)
    assert.equals(1, #state.installs)
  end)

  it('leaves other plugin-owned adapters untouched', function()
    assert.equals('plugin-owned', dap.adapters.coreclr.command)
    assert.is_nil(dap.configurations.rust)
    drain()
    assert.same({}, state.refreshes)
  end)

  it('waits for a partially linked adapter instead of caching an empty executable', function()
    state.installing.debugpy = true
    state.promote('debugpy')
    local result
    resolve(function(adapter)
      result = adapter
    end, configs[1])
    drain()
    state.refresh()
    drain()
    assert.is_nil(result)
    state.finish('debugpy', true)
    drain()
    assert.equals('debugpy-adapter', result.command)
  end)

  it('explains repeated Rust debug launches after codelldb fails', function()
    local original_notify = vim.notify
    local messages = {}
    vim.notify = function(message)
      messages[#messages + 1] = message
    end
    local results = {}
    local function launch()
      dap.adapters.codelldb(function(adapter)
        results[#results + 1] = adapter
      end, { type = 'codelldb' })
    end
    launch()
    drain()
    state.refresh()
    drain()
    state.finish('codelldb', false)
    drain()
    messages = {}
    launch()
    drain()
    vim.notify = original_notify
    assert.same({}, results)
    assert.equals(1, #state.installs)
    assert.equals(1, #messages)
    assert.matches(':MasonInstall codelldb', messages[1], 1, true)
  end)

  for _, success in ipairs({ true, false }) do
    it(
      'resolves the Rust adapter only after a successful install: ' .. tostring(success),
      function()
        local original_notify = vim.notify
        vim.notify = function() end
        local result
        local config = { type = 'codelldb', request = 'launch' }
        dap.adapters.codelldb(function(adapter)
          result = adapter
        end, config)
        drain()
        state.refresh()
        drain()
        assert.same({ 'codelldb' }, state.installs)
        assert.is_nil(result)
        state.finish('codelldb', success)
        drain()
        vim.notify = original_notify
        if success then
          assert.same(vim.g.rustaceanvim.dap.adapter, result)
        else
          assert.is_nil(result)
        end
        assert.equals('codelldb', config.type)
      end
    )
  end
end)
