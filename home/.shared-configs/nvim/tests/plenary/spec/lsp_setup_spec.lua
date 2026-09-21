local h = require('project_settings_harness')

describe('LSP server setup', function()
  local original
  local original_modules
  local base
  local enabled_configs
  local module_names = { 'configs.plugins.nvim-lspconfig', 'configs.lsp' }

  local function use_servers(servers)
    package.loaded['configs.lsp'] = { servers = servers }
  end

  before_each(function()
    base = h.new_base()
    enabled_configs = {}
    original_modules = {}
    for _, name in ipairs(module_names) do
      original_modules[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    original = {
      configs = vim.lsp.config._configs,
      enabled_configs = vim.lsp._enabled_configs,
      enable = vim.lsp.enable,
      codelens_enable = vim.lsp.codelens.enable,
      diagnostic_config = vim.diagnostic.config,
      keymap_set = vim.keymap.set,
      cwd = vim.fn.getcwd(),
    }
    vim.lsp.config._configs = {}
    vim.lsp._enabled_configs = {}
    vim.lsp.enable = function(names)
      for _, name in ipairs(type(names) == 'table' and names or { names }) do
        enabled_configs[name] = vim.deepcopy(vim.lsp.config[name])
      end
    end
    vim.lsp.codelens.enable = function() end
    vim.diagnostic.config = function() end
    vim.keymap.set = function() end
  end)

  after_each(function()
    for _, name in ipairs({ 'kickstart-lsp-attach', 'kickstart-lsp-detach' }) do
      pcall(vim.api.nvim_del_augroup_by_name, name)
    end
    vim.lsp.config._configs = original.configs
    vim.lsp._enabled_configs = original.enabled_configs
    vim.lsp.enable = original.enable
    vim.lsp.codelens.enable = original.codelens_enable
    vim.diagnostic.config = original.diagnostic_config
    vim.keymap.set = original.keymap_set
    for _, name in ipairs(module_names) do
      package.loaded[name] = original_modules[name]
    end
    vim.cmd.cd(vim.fn.fnameescape(original.cwd))
    vim.fn.delete(base, 'rf')
  end)

  it('preserves server initialization and applies project settings from the client root', function()
    local root = h.mktemp_root(base, 'client-root')
    local other_root = h.mktemp_root(base, 'current-directory')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['Lua.completion.callSnippet'] = 'Replace',
      ['Lua.workspace.checkThirdParty'] = false,
    })
    h.write_json(h.join(other_root, '.vscode', 'settings.json'), {
      ['Lua.completion.callSnippet'] = 'Both',
    })
    vim.cmd.cd(vim.fn.fnameescape(other_root))

    local native_calls = 0
    vim.lsp.config('lua_ls', {
      settings = { Lua = { completion = { callSnippet = 'Disable' } } },
      before_init = function(params, config)
        native_calls = native_calls + 1
        params.initializationOptions = { from_native_hook = true }
        config.settings.Lua.runtime = { version = 'LuaJIT' }
        config.settings.Lua.completion.callSnippet = 'Disable'
      end,
    })
    use_servers({ lua_ls = { root_dir = root } })
    require('configs.plugins.nvim-lspconfig')

    local config = vim.deepcopy(vim.lsp.config.lua_ls)
    local params = {}
    config.before_init(params, config)

    assert.equals(1, native_calls)
    assert.same({ from_native_hook = true }, params.initializationOptions)
    assert.equals('LuaJIT', config.settings.Lua.runtime.version)
    assert.equals('Replace', config.settings.Lua.completion.callSnippet)
    assert.is_false(config.settings.Lua.workspace.checkThirdParty)
  end)

  it('configures every server before enabling it for already open buffers', function()
    vim.lsp.config('lua_ls', {
      settings = { Lua = { completion = { callSnippet = 'Disable' } } },
    })
    vim.lsp.config('gopls', { settings = { gopls = { completeUnimported = false } } })
    use_servers({
      lua_ls = {
        settings = { Lua = { completion = { callSnippet = 'Replace' } } },
      },
      gopls = {
        settings = { gopls = { completeUnimported = true } },
      },
    })

    require('configs.plugins.nvim-lspconfig')

    assert.equals(2, vim.tbl_count(enabled_configs))
    assert.equals('Replace', enabled_configs.lua_ls.settings.Lua.completion.callSnippet)
    assert.is_true(enabled_configs.gopls.settings.gopls.completeUnimported)
  end)
end)
