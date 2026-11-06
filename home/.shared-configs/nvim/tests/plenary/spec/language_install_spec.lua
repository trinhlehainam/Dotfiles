describe('language installation', function()
  local saved, registry, state, enabled, buffers, languages, current_buf
  local modules = {
    'mason-registry',
    'mason-core.installer.InstallLocation',
    'utils.mason_install',
    'features.language_install',
    'configs.lsp',
    'rustaceanvim.lsp',
  }
  local original_enable, original_notify

  local function drain()
    vim.wait(20, function()
      return false
    end, 1)
  end
  local function buffer(ft, special)
    local buf = vim.api.nvim_create_buf(true, false)
    buffers[#buffers + 1] = buf
    vim.bo[buf].buftype = special or ''
    vim.bo[buf].filetype = ft
    return buf
  end
  local function setup()
    local config = { by_filetype = {}, servers = {}, server_tools = {} }
    for _, language in ipairs(languages) do
      for _, ft in ipairs(language.filetypes) do
        config.by_filetype[ft] = config.by_filetype[ft] or {}
        table.insert(config.by_filetype[ft], language)
      end
      config.servers = vim.tbl_extend('force', config.servers, language.servers or {})
      config.server_tools =
        vim.tbl_extend('force', config.server_tools, language.server_tools or {})
    end
    package.loaded['configs.lsp'] = config
    require('features.language_install').setup()
  end

  before_each(function()
    saved = {}
    for _, name in ipairs(modules) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    registry, state = require('fake_mason').new()
    package.loaded['mason-registry'] = registry
    package.loaded['mason-core.installer.InstallLocation'] = state.location
    enabled, buffers = {}, {}
    current_buf = vim.api.nvim_get_current_buf()
    original_enable, original_notify = vim.lsp.enable, vim.notify
    vim.lsp.enable = function(names)
      for _, name in ipairs(type(names) == 'table' and names or { names }) do
        enabled[name] = (enabled[name] or 0) + 1
      end
    end
    vim.notify = function() end
    languages = {
      {
        filetypes = { 'python' },
        tools = { 'pyright', 'ruff' },
        servers = { pyright = {}, ruff = {} },
        server_tools = { pyright = { 'pyright' }, ruff = { 'ruff' } },
      },
      {
        filetypes = { 'php' },
        tools = { 'intelephense', 'phpcs' },
        servers = { intelephense = {} },
        server_tools = { intelephense = { 'intelephense' } },
      },
    }
  end)

  after_each(function()
    drain()
    state.cleanup()
    pcall(vim.api.nvim_del_augroup_by_name, 'dotfiles-language-install')
    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    vim.api.nvim_set_current_buf(current_buf)
    vim.lsp.enable, vim.notify = original_enable, original_notify
    for _, name in ipairs(modules) do
      package.loaded[name] = saved[name]
    end
  end)

  it('does no installs at startup, enabling only ready servers', function()
    state.seed('pyright')
    setup()
    drain()
    assert.same({ pyright = 1 }, enabled)
    assert.same({}, state.refreshes)
    assert.same({}, state.installs)
  end)

  it('does not recheck receipts for enabled servers after another install', function()
    state.seed('pyright')
    setup()
    drain()
    local installer = require('utils.mason_install')
    local is_ready, checked = installer.is_ready, {}
    installer.is_ready = function(name)
      checked[name] = (checked[name] or 0) + 1
      return is_ready(name)
    end
    state.finish('ruff', true)
    drain()
    assert.same({ pyright = 1, ruff = 1 }, enabled)
    assert.is_nil(checked.pyright)
  end)

  it('rechecks only the opened language when packages are already installed', function()
    setup()
    -- Another Neovim process can install packages without this registry emitting events.
    state.seed('pyright')
    state.seed('ruff')
    local installer = require('utils.mason_install')
    local is_ready, checked = installer.is_ready, {}
    installer.is_ready = function(name)
      checked[name] = true
      return is_ready(name)
    end
    buffer('python')
    drain()
    assert.same({ pyright = 1, ruff = 1 }, enabled)
    assert.same({ pyright = true, ruff = true }, checked)
  end)

  it('installs only an opened language once across multiple buffers', function()
    setup()
    buffer('python')
    buffer('python')
    drain()
    state.refresh()
    drain()
    table.sort(state.installs)
    assert.same({ 'pyright', 'ruff' }, state.installs)
    state.finish('pyright', true)
    state.finish('ruff', true)
    drain()
    assert.same({ pyright = 1, ruff = 1 }, enabled)
  end)

  it('does not enable a partially linked server when another installation finishes', function()
    setup()
    buffer('python')
    drain()
    state.refresh()
    drain()
    state.promote('pyright')
    state.finish('ruff', true)
    drain()
    assert.same({ ruff = 1 }, enabled)
    state.finish('pyright', true)
    drain()
    assert.same({ pyright = 1, ruff = 1 }, enabled)
  end)

  it('ignores special and unrelated buffers', function()
    setup()
    buffer('python', 'nofile')
    buffer('php', 'prompt')
    buffer('text')
    drain()
    assert.same({}, state.refreshes)
    assert.same({}, enabled)
  end)

  it('catches buffers whose FileType ran before setup', function()
    buffer('php')
    setup()
    drain()
    state.refresh()
    drain()
    table.sort(state.installs)
    assert.same({ 'intelephense', 'phpcs' }, state.installs)
  end)

  it('keeps a failed server disabled without blocking another server', function()
    setup()
    buffer('python')
    drain()
    state.refresh()
    drain()
    state.finish('pyright', false)
    state.finish('ruff', true)
    drain()
    assert.same({ ruff = 1 }, enabled)
    state.finish('pyright', true)
    drain()
    assert.same({ pyright = 1, ruff = 1 }, enabled)
  end)

  it('does not wait for a linter before enabling its language server', function()
    setup()
    buffer('php')
    drain()
    state.refresh()
    drain()
    state.finish('intelephense', true)
    drain()
    assert.equals(1, enabled.intelephense)
    state.finish('phpcs', false)
    drain()
    assert.equals(1, enabled.intelephense)
  end)

  it('waits for every required server dependency, including Vue for vtsls', function()
    languages = {
      {
        filetypes = { 'typescript', 'vue' },
        tools = { 'vtsls', 'vue-language-server' },
        servers = { vtsls = {} },
        server_tools = { vtsls = { 'vtsls', 'vue-language-server' } },
      },
    }
    setup()
    buffer('typescript')
    drain()
    state.refresh()
    drain()
    state.finish('vtsls', true)
    drain()
    assert.is_nil(enabled.vtsls)
    state.finish('vue-language-server', true)
    drain()
    assert.equals(1, enabled.vtsls)
  end)

  it('checks project conditions per buffer instead of caching a global decision', function()
    local allowed
    languages[1].condition = function(buf)
      return buf == allowed
    end
    setup()
    local first = buffer('python')
    drain()
    assert.same({}, state.refreshes)
    allowed = first
    vim.api.nvim_exec_autocmds('FileType', { buffer = first })
    drain()
    state.refresh()
    drain()
    table.sort(state.installs)
    assert.same({ 'pyright', 'ruff' }, state.installs)
  end)

  it('starts plugin-owned servers after installation in the original buffer', function()
    local started
    languages = {
      {
        filetypes = { 'rust' },
        tools = { 'rust-analyzer' },
        on_ready = function(buf)
          started = { buf, vim.api.nvim_get_current_buf() }
        end,
      },
    }
    setup()
    local rust = buffer('rust')
    drain()
    state.refresh()
    drain()
    state.finish('rust-analyzer', true)
    drain()
    assert.same({ rust, rust }, started)
    assert.same({}, enabled)
  end)

  it('starts Rust only for named file buffers, preserving the plugin default', function()
    local starts = {}
    package.loaded['rustaceanvim.lsp'] = {
      start = function(buf)
        starts[#starts + 1] = buf or 0
      end,
    }
    languages = { dofile(vim.g.project_settings_test_repo_root .. '/lua/configs/lsp/rust.lua') }
    state.seed('rust-analyzer')
    setup()
    buffer('rust')
    drain()
    assert.same({}, starts)
    local named = buffer('rust')
    vim.api.nvim_buf_set_name(named, vim.fn.tempname() .. '.rs')
    drain()
    assert.same({ named }, starts)
  end)

  for _, extension in ipairs({ 'cs', 'razor', 'cshtml' }) do
    it('requests Roslyn for a .' .. extension .. ' file', function()
      languages = { dofile(vim.g.project_settings_test_repo_root .. '/lua/configs/lsp/csharp.lua') }
      setup()
      buffer(vim.filetype.match({ filename = 'Example.' .. extension }))
      drain()
      state.refresh()
      drain()
      table.sort(state.installs)
      assert.same({ 'csharpier', 'roslyn' }, state.installs)
      state.finish('roslyn', true)
      drain()
      assert.equals(1, enabled.roslyn)
    end)
  end

  it(
    'recovers plugin-owned servers on manual retry without restarting them for unrelated installs',
    function()
      local starts = 0
      languages = {
        {
          filetypes = { 'rust' },
          tools = { 'rust-analyzer' },
          on_ready = function()
            starts = starts + 1
          end,
        },
      }
      setup()
      buffer('rust')
      drain()
      state.refresh()
      drain()
      state.finish('rust-analyzer', false)
      drain()
      assert.equals(0, starts)
      state.finish('rust-analyzer', true)
      drain()
      assert.equals(1, starts)
      state.finish('unrelated', true)
      drain()
      assert.equals(1, starts)
    end
  )

  for _, change in ipairs({ 'delete', 'filetype', 'project' }) do
    it('skips a stale plugin buffer after ' .. change, function()
      local starts, allowed = 0, true
      languages = {
        {
          filetypes = { 'rust' },
          tools = { 'rust-analyzer' },
          condition = function()
            return allowed
          end,
          on_ready = function()
            starts = starts + 1
          end,
        },
      }
      setup()
      local buf = buffer('rust')
      drain()
      state.refresh()
      drain()
      if change == 'delete' then
        vim.api.nvim_buf_delete(buf, { force = true })
      elseif change == 'filetype' then
        vim.bo[buf].filetype = 'text'
      else
        allowed = false
      end
      state.finish('rust-analyzer', true)
      drain()
      assert.equals(0, starts)
    end)
  end
end)
