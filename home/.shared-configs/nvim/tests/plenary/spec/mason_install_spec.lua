describe('on-demand Mason installation', function()
  local original, registry, state, installer, warnings

  local function drain()
    vim.wait(20, function()
      return false
    end, 1)
  end

  before_each(function()
    original = {
      registry = package.loaded['mason-registry'],
      location = package.loaded['mason-core.installer.InstallLocation'],
      installer = package.loaded['utils.mason_install'],
      notify = vim.notify,
    }
    registry, state = require('fake_mason').new()
    package.loaded['mason-registry'] = registry
    package.loaded['mason-core.installer.InstallLocation'] = state.location
    package.loaded['utils.mason_install'] = nil
    warnings = {}
    vim.notify = function(message)
      warnings[#warnings + 1] = message
    end
    installer = require('utils.mason_install')
  end)

  after_each(function()
    drain()
    package.loaded['mason-registry'] = original.registry
    package.loaded['mason-core.installer.InstallLocation'] = original.location
    state.cleanup()
    package.loaded['utils.mason_install'] = original.installer
    vim.notify = original.notify
  end)

  it('uses installed packages without refreshing the registry', function()
    state.seed('pyright')
    local done
    installer.ensure({ 'pyright' }, function(ok)
      done = ok
    end)
    drain()
    assert.is_true(done)
    assert.same({}, state.refreshes)
    assert.same({}, state.installs)
  end)

  it('coalesces refreshes and shared packages, and waits for every dependency', function()
    local first, second
    installer.ensure({ 'vtsls', 'vue' }, function(ok)
      first = ok
    end)
    installer.ensure({ 'vue' }, function(ok)
      second = ok
    end)
    drain()
    assert.equals(1, #state.refreshes)
    state.refresh()
    drain()
    table.sort(state.installs)
    assert.same({ 'vtsls', 'vue' }, state.installs)
    state.finish('vue', true)
    drain()
    assert.is_nil(first)
    assert.is_true(second)
    state.finish('vtsls', true)
    drain()
    assert.is_true(first)
  end)

  it('joins an installation started by the Mason UI', function()
    state.installing.pyright = true
    local done
    installer.ensure({ 'pyright' }, function(ok)
      done = ok
    end)
    drain()
    state.refresh()
    drain()
    assert.same({}, state.installs)
    assert.is_nil(done)
    state.finish('pyright', true)
    drain()
    assert.is_true(done)
  end)

  it('accepts packages installed while registry refresh was pending', function()
    local done
    installer.ensure({ 'ruff' }, function(ok)
      done = ok
    end)
    drain()
    state.seed('ruff')
    state.refresh()
    drain()
    assert.is_true(done)
    assert.same({}, state.installs)
  end)

  it('warns once on failure, avoids retries, and recovers after manual installation', function()
    local results = {}
    local function finished(ok)
      results[#results + 1] = ok
    end
    installer.ensure({ 'ruff' }, finished)
    drain()
    state.refresh()
    drain()
    state.finish('ruff', false)
    drain()
    installer.ensure({ 'ruff' }, finished)
    drain()
    assert.same({ false, false }, results)
    assert.equals(1, #warnings)
    assert.matches(':MasonInstall ruff', warnings[1], 1, true)
    assert.equals(1, #state.installs)
    state.finish('ruff', true)
    drain()
    installer.ensure({ 'ruff' }, finished)
    drain()
    assert.same({ false, false, true }, results)
  end)

  for _, name in ipairs({ 'unknown', 'throws' }) do
    it('reports ' .. name .. ' without crashing or blocking other packages', function()
      local done
      installer.ensure({ name, 'ruff' }, function(ok)
        done = ok
      end)
      drain()
      state.refresh(false)
      drain()
      state.finish('ruff', true)
      drain()
      assert.is_false(done)
      assert.equals(1, #warnings)
    end)
  end

  it('collects requests arriving during an asynchronous refresh', function()
    installer.ensure({ 'pyright' }, function() end)
    drain()
    installer.ensure({ 'ruff' }, function() end)
    drain()
    assert.equals(1, #state.refreshes)
    state.refresh()
    drain()
    table.sort(state.installs)
    assert.same({ 'pyright', 'ruff' }, state.installs)
    state.finish('pyright', true)
    state.finish('ruff', true)
  end)

  it('completes an empty dependency list asynchronously', function()
    local done
    installer.ensure({}, function(ok)
      done = ok
    end)
    assert.is_nil(done)
    drain()
    assert.is_true(done)
  end)

  for _, phase in ipairs({ 'before request', 'during refresh' }) do
    it('waits for links and receipt when a package directory appears ' .. phase, function()
      local done
      state.installing.pyright = true
      if phase == 'before request' then
        state.promote('pyright')
      end
      installer.ensure({ 'pyright' }, function(ok)
        done = ok
      end)
      drain()
      state.promote('pyright')
      state.refresh()
      drain()
      assert.is_nil(done)
      assert.same({}, state.installs)
      state.finish('pyright', true)
      drain()
      assert.is_true(done)
    end)
  end

  it('uses the cached registry and releases the queue if refresh throws', function()
    registry.refresh = function()
      error('corrupt registry timestamp')
    end
    local done
    installer.ensure({ 'pyright' }, function(ok)
      done = ok
    end)
    drain()
    assert.same({ 'pyright' }, state.installs)
    state.finish('pyright', true)
    drain()
    assert.is_true(done)
    installer.ensure({ 'ruff' }, function() end)
    drain()
    assert.same({ 'pyright', 'ruff' }, state.installs)
  end)
end)
