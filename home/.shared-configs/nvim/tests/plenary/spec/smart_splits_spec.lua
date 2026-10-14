describe('smart-splits multiplexer integration', function()
  local plugins = {
    { env = 'SMART_SPLITS_DIR', name = 'smart-splits.nvim' },
    { env = 'SMART_SPLITS_TMUX_DIR', name = 'backend-tmux' },
    { env = 'SMART_SPLITS_WEZTERM_DIR', name = 'backend-wezterm' },
  }
  for _, plugin in ipairs(plugins) do
    plugin.path = vim.env[plugin.env] or (vim.fn.stdpath('data') .. '/lazy/' .. plugin.name)
    assert(vim.fn.isdirectory(plugin.path) == 1, plugin.name .. ' missing; set ' .. plugin.env)
  end
  local env_names = { 'TMUX', 'TMUX_PANE', 'WEZTERM_PANE', 'SMART_SPLITS_WEZTERM', 'FLATPAK_ID' }
  local mappings = {
    { key = '<C-h>', direction = 'left', flag = '-L', action = 'move' },
    { key = '<C-j>', direction = 'down', flag = '-D', action = 'move' },
    { key = '<C-k>', direction = 'up', flag = '-U', action = 'move' },
    { key = '<C-l>', direction = 'right', flag = '-R', action = 'move' },
    { key = '<A-,>', direction = 'left', flag = '-L', action = 'resize' },
    { key = '<A-.>', direction = 'right', flag = '-R', action = 'resize' },
    { key = '<A-u>', direction = 'up', flag = '-U', action = 'resize' },
    { key = '<A-d>', direction = 'down', flag = '-D', action = 'resize' },
  }
  local original
  local tmux
  local userscript
  local tmux_marker
  local tmux_operations
  local user_vars
  local requests

  local function configure()
    local plugin = require('plugins.smart-splits')
    plugin.config(plugin, plugin.opts)
  end

  local function press(key)
    local mapping = vim.fn.maparg(key, 'n', false, true)
    assert.is_function(mapping.callback)
    mapping.callback()
  end

  before_each(function()
    original = { env = {}, keymaps = {}, runtimepath = vim.o.runtimepath }
    for _, name in ipairs(env_names) do
      original.env[name] = vim.env[name]
      vim.env[name] = nil
    end
    for _, mapping in ipairs(mappings) do
      original.keymaps[mapping.key] = vim.fn.maparg(mapping.key, 'n', false, true)
    end
    for _, plugin in ipairs(plugins) do
      vim.opt.runtimepath:prepend(plugin.path)
    end

    vim.cmd('silent only!')
    require('smart-splits.config').reset()
    require('smart-splits.backend').reset()
    require('smart-splits-backend-tmux.activate').reset()
    require('smart-splits-backend-tmux').setup({})
    require('smart-splits-backend-wezterm').setup({})
    tmux = require('smart-splits-backend-tmux.tmux')
    userscript = require('smart-splits-backend-wezterm.userscript')
    original.write = userscript._write
    tmux_marker = 0
    tmux_operations = {}
    user_vars = {}
    requests = {}

    -- Replace only the external tmux process and terminal OSC write.
    local function run_tmux(command)
      local operation = command[4]
      if operation == 'show-options' then
        return tostring(tmux_marker), 0
      elseif operation == 'set-option' then
        tmux_marker = tonumber(command[#command])
      elseif operation == 'select-pane' or operation == 'resize-pane' then
        tmux_operations[#tmux_operations + 1] = { operation, command[5], command[6] }
      end
      return '', 0
    end
    tmux.set_runner(run_tmux, function(command)
      run_tmux(command)
      return true
    end)
    userscript._write = function(sequence)
      local name, encoded = sequence:match('^\027%]1337;SetUserVar=([^=]+)=(.-)\007$')
      assert.is_not_nil(name)
      local value = vim.base64.decode(encoded)
      if name == 'SMART_SPLITS_REQ' then
        requests[#requests + 1] = vim.json.decode(value)
      else
        user_vars[name] = value
      end
      return true
    end
  end)

  after_each(function()
    vim.cmd('silent only!')
    tmux.reset_runner()
    userscript._write = original.write
    require('smart-splits-backend-tmux.activate').reset()
    for _, group in ipairs({ 'smart_splits_backend_wezterm', 'wezterm_user_vars' }) do
      pcall(vim.api.nvim_del_augroup_by_name, group)
    end
    require('smart-splits.config').reset()
    require('smart-splits.backend').reset()
    for _, name in ipairs(env_names) do
      vim.env[name] = original.env[name]
    end
    for _, mapping in ipairs(mappings) do
      pcall(vim.keymap.del, 'n', mapping.key)
      local previous = original.keymaps[mapping.key]
      if next(previous) then
        vim.fn.mapset('n', false, previous)
      end
    end
    vim.o.runtimepath = original.runtimepath
  end)

  it('claims tmux keys and delegates all edge mappings when tmux runs inside WezTerm', function()
    vim.env.TMUX = '/tmp/smart-splits-test.sock,1,0'
    vim.env.TMUX_PANE = '%7'
    vim.env.WEZTERM_PANE = '1'
    vim.env.SMART_SPLITS_WEZTERM = '1'

    configure()

    assert.equals(1, tmux_marker)
    local expected = {}
    for _, mapping in ipairs(mappings) do
      press(mapping.key)
      expected[#expected + 1] = {
        mapping.action == 'move' and 'select-pane' or 'resize-pane',
        mapping.flag,
        mapping.action == 'resize' and '3' or nil,
      }
    end
    assert.same(expected, tmux_operations)
    assert.same({}, user_vars)
    assert.same({}, requests)

    vim.api.nvim_exec_autocmds('VimSuspend', { group = 'SmartSplitsBackendTmux' })
    assert.equals(0, tmux_marker)
    vim.api.nvim_exec_autocmds('VimResume', { group = 'SmartSplitsBackendTmux' })
    assert.equals(1, tmux_marker)
    vim.api.nvim_exec_autocmds('VimLeavePre', { group = 'SmartSplitsBackendTmux' })
    assert.equals(0, tmux_marker)
  end)

  it('delegates all edge mappings to WezTerm outside tmux', function()
    vim.env.WEZTERM_PANE = '1'
    vim.env.SMART_SPLITS_WEZTERM = '1'

    configure()

    assert.equals('true', user_vars.IS_NVIM)
    local expected = {}
    for _, mapping in ipairs(mappings) do
      press(mapping.key)
      expected[#expected + 1] = {
        action = mapping.action,
        dir = mapping.direction,
        amount = mapping.action == 'resize' and 3 or nil,
      }
    end
    assert.same(expected, requests)
    assert.same({}, tmux_operations)

    vim.api.nvim_exec_autocmds('VimSuspend', { group = 'smart_splits_backend_wezterm' })
    assert.equals('false', user_vars.IS_NVIM)
    vim.api.nvim_exec_autocmds('VimResume', { group = 'smart_splits_backend_wezterm' })
    assert.equals('true', user_vars.IS_NVIM)
    vim.api.nvim_exec_autocmds('VimLeavePre', { group = 'smart_splits_backend_wezterm' })
    assert.equals('false', user_vars.IS_NVIM)
  end)

  it('moves between Neovim splits without a multiplexer', function()
    configure()
    vim.cmd('vsplit')
    vim.cmd('wincmd l')
    local right = vim.api.nvim_get_current_win()
    vim.cmd('wincmd h')
    local left = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(right)

    press('<C-h>')

    assert.equals(left, vim.api.nvim_get_current_win())
    assert.is_nil(require('smart-splits.backend').resolve())
    assert.same({}, tmux_operations)
    assert.same({}, requests)
  end)
end)
