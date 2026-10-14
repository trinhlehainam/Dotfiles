describe('WezTerm navigation routing', function()
  local wezterm_root = vim.fn.fnamemodify(vim.g.project_settings_test_repo_root, ':h:h')
    .. '/dot_config/wezterm'
  local module_names = { 'wezterm', 'utils.pane' }
  local original_modules
  local navigation

  before_each(function()
    original_modules = {}
    for _, name in ipairs(module_names) do
      original_modules[name] = package.loaded[name]
    end
    package.loaded.wezterm = {
      action_callback = function(callback)
        return callback
      end,
      action = {
        SendKey = function(key)
          return { SendKey = key }
        end,
        ActivatePaneDirection = function(direction)
          return { ActivatePaneDirection = direction }
        end,
        AdjustPaneSize = function(size)
          return { AdjustPaneSize = size }
        end,
      },
    }
    package.loaded['utils.pane'] = dofile(wezterm_root .. '/utils/pane.lua')
    navigation = dofile(wezterm_root .. '/utils/navigation.lua')
  end)

  after_each(function()
    for _, name in ipairs(module_names) do
      package.loaded[name] = original_modules[name]
    end
  end)

  local function route(binding, user_vars, pane_count, process)
    local action
    local current_pane = {
      get_foreground_process_name = function()
        return process
      end,
      get_user_vars = function()
        return user_vars
      end,
    }
    local win = {
      active_tab = function()
        return {
          panes = function()
            return pane_count == 1 and { current_pane } or { current_pane, {} }
          end,
        }
      end,
      perform_action = function(_, selected_action, target_pane)
        assert.equals(current_pane, target_pane)
        action = selected_action
      end,
    }
    binding.action(win, current_pane)
    return action
  end

  for _, operation in ipairs({
    { name = 'move', key = 'h', mods = 'CTRL', native = { ActivatePaneDirection = 'Left' } },
    { name = 'resize', key = ',', mods = 'META', native = { AdjustPaneSize = { 'Left', 3 } } },
  }) do
    for _, marker in ipairs({ 'IS_NVIM', 'IS_TMUX' }) do
      it('passes ' .. operation.name .. ' keys into ' .. marker .. ' with two panes', function()
        local binding = navigation[operation.name](operation.key, 'Left')

        assert.same(
          { SendKey = { key = operation.key, mods = operation.mods } },
          route(binding, { [marker] = 'true' }, 2)
        )
      end)
    end

    it('uses WezTerm ' .. operation.name .. ' for a shell with two panes', function()
      local binding = navigation[operation.name](operation.key, 'Left')

      assert.same(operation.native, route(binding, { IS_NVIM = '', IS_TMUX = '' }, 2))
    end)

    it('passes ' .. operation.name .. ' keys into a single pane', function()
      local binding = navigation[operation.name](operation.key, 'Left')

      assert.same(
        { SendKey = { key = operation.key, mods = operation.mods } },
        route(binding, {}, 1)
      )
    end)

    for _, scenario in ipairs({
      { name = 'local tmux without Bash markers', process = '/usr/local/bin/tmux', pass = true },
      { name = 'shell after tmux detaches', process = '/bin/bash', marker = 'true', pass = false },
      { name = 'SSH tmux', process = '/usr/bin/ssh', marker = 'true', pass = true },
      {
        name = 'WSL tmux',
        process = 'C:\\Windows\\System32\\wsl.exe',
        marker = 'true',
        pass = true,
      },
    }) do
      it('routes ' .. operation.name .. ' for ' .. scenario.name, function()
        local binding = navigation[operation.name](operation.key, 'Left')
        local expected = scenario.pass
            and { SendKey = { key = operation.key, mods = operation.mods } }
          or operation.native

        assert.same(expected, route(binding, { IS_TMUX = scenario.marker }, 2, scenario.process))
      end)
    end
  end
end)
