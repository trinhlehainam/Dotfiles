describe('language tooling registry', function()
  local saved_modules
  local saved_preload

  before_each(function()
    saved_modules = { ['configs.lsp'] = package.loaded['configs.lsp'] }
    saved_preload = package.preload['configs.lsp.lua']
    package.loaded['configs.lsp'] = nil
    local root = vim.g.project_settings_test_repo_root .. '/lua/configs/lsp'
    for name in vim.fs.dir(root) do
      local language = name:match('^(.*)%.lua$')
      if language and language ~= 'init' and language ~= 'types' then
        local module = 'configs.lsp.' .. language
        saved_modules[module] = { value = package.loaded[module] }
        package.loaded[module] = {}
      end
    end
  end)

  after_each(function()
    package.loaded['configs.lsp'] = saved_modules['configs.lsp']
    saved_modules['configs.lsp'] = nil
    for module, saved in pairs(saved_modules) do
      package.loaded[module] = saved.value
    end
    package.preload['configs.lsp.lua'] = saved_preload
  end)

  it(
    'merges tools and linters once in language order with false winning for lint-on-save',
    function()
      package.loaded['configs.lsp.lua'] = {
        filetypes = { 'lua' },
        tools = { 'shared', 'first' },
        parsers = { 'shared' },
        dap = { 'shared' },
        linters = { test = { 'first', 'shared' } },
        lint_on_save = false,
      }
      package.loaded['configs.lsp.python'] = {
        filetypes = { 'python' },
        tools = { 'shared', 'second' },
        parsers = { 'shared', 'second' },
        dap = { 'shared', 'second' },
        linters = { test = { 'shared', 'second' } },
      }

      local registry = require('configs.lsp')

      assert.same({ 'shared', 'first', 'second' }, registry.tools)
      assert.same({ 'shared', 'second' }, registry.parsers)
      assert.same({ 'shared', 'second' }, registry.dap)
      assert.same({ 'first', 'shared', 'second' }, registry.linters.test)
      assert.is_false(registry.lint_on_save.test)
    end
  )

  it('rejects competing server owners', function()
    package.loaded['configs.lsp.lua'] = { servers = { duplicate = {} } }
    package.loaded['configs.lsp.python'] = { servers = { duplicate = {} } }

    local ok, err = pcall(require, 'configs.lsp')
    assert.is_false(ok)
    assert.matches('Duplicate LSP server: duplicate', err, 1, true)
  end)

  it('rejects an editing tool list with no installation trigger', function()
    package.loaded['configs.lsp.lua'] = { tools = { 'lua-language-server' } }
    local ok, err = pcall(require, 'configs.lsp')
    assert.is_false(ok)
    assert.matches('Missing install filetypes: lua', err, 1, true)
  end)

  it('indexes explicit filetypes, never inferring tool demand from parser companions', function()
    local language = {
      filetypes = { 'cs' },
      parsers = { 'c_sharp', 'json', 'sql' },
      tools = { 'roslyn' },
      debug_tools = { 'netcoredbg' },
      servers = { roslyn = {} },
      server_tools = { roslyn = { 'roslyn' } },
    }
    package.loaded['configs.lsp.csharp'] = language
    local registry = require('configs.lsp')
    assert.same({ language }, registry.by_filetype.cs)
    assert.is_nil(registry.by_filetype.json)
    assert.same({ 'roslyn' }, registry.server_tools.roslyn)
    assert.same({ 'roslyn', 'netcoredbg' }, registry.tools)
    assert.same({ 'roslyn' }, registry.by_filetype.cs[1].tools)
  end)

  it('rejects a required server package missing from the install list', function()
    package.loaded['configs.lsp.lua'] = {
      filetypes = { 'lua' },
      tools = {},
      servers = { lua_ls = {} },
      server_tools = { lua_ls = { 'lua-language-server' } },
    }
    local ok, err = pcall(require, 'configs.lsp')
    assert.is_false(ok)
    assert.matches('Missing server tool: lua-language-server', err, 1, true)
  end)

  it('rejects server dependencies declared by the wrong language module', function()
    package.loaded['configs.lsp.lua'] = { server_tools = { missing = {} } }
    local ok, err = pcall(require, 'configs.lsp')
    assert.is_false(ok)
    assert.matches('Unknown server owner: missing', err, 1, true)
  end)

  it('rejects competing formatter chains', function()
    package.loaded['configs.lsp.lua'] = { formatters = { duplicate = { 'one' } } }
    package.loaded['configs.lsp.python'] = { formatters = { duplicate = { 'two' } } }

    local ok, err = pcall(require, 'configs.lsp')
    assert.is_false(ok)
    assert.matches('Duplicate formatter filetype: duplicate', err, 1, true)
  end)

  it('preserves required module errors instead of silently losing a language', function()
    package.loaded['configs.lsp.lua'] = nil
    package.preload['configs.lsp.lua'] = function()
      error('broken language configuration')
    end

    local ok, err = pcall(require, 'configs.lsp')
    assert.is_false(ok)
    assert.matches('broken language configuration', err, 1, true)
  end)

  it('loads test adapters only when neotest requests them', function()
    local calls = 0
    local adapter = { name = 'test-adapter' }
    package.loaded['configs.lsp.lua'] = {
      neotest = function()
        calls = calls + 1
        return adapter
      end,
    }

    local registry = require('configs.lsp')
    assert.equals(0, calls)
    assert.same({ adapter }, registry.get_neotest_adapters())
    assert.equals(1, calls)
  end)
end)
