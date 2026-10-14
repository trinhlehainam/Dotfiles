describe('tmux markers across client sessions', function()
  local repo_home = vim.fn.fnamemodify(vim.g.project_settings_test_repo_root, ':h:h')
  local directory
  local socket
  local terminal
  local output
  local original_env

  local function tmux(...)
    local command = vim.list_extend({ 'tmux', '-S', socket }, { ... })
    local result = vim.system(command, { text = true, timeout = 5000 }):wait()
    assert.equals(0, result.code, result.stderr)
    return vim.trim(result.stdout)
  end

  local function wait_for(text)
    assert.is_true(
      vim.wait(5000, function()
        return output:find(text, 1, true) ~= nil
      end, 20),
      'Terminal did not emit ' .. vim.inspect(text)
    )
  end

  before_each(function()
    assert.equals(1, vim.fn.executable('tmux'), 'This integration test requires tmux')
    assert.equals(1, vim.fn.executable('bash'), 'This integration test requires Bash')
    original_env = { TMUX = vim.env.TMUX, TMUX_PANE = vim.env.TMUX_PANE }
    vim.env.TMUX = nil
    vim.env.TMUX_PANE = nil
    directory = vim.fn.tempname()
    vim.fn.mkdir(directory, 'p')
    socket = directory .. '/tmux.sock'
    output = ''

    -- Load production integration only; avoid TPM and unrelated prompt plugins.
    local config = table.concat(vim.fn.readfile(repo_home .. '/dot_tmux.conf'), '\n')
    local section = assert(config:match('# #region smart%-splits(.-)# #endregion smart%-splits'))
    vim.fn.writefile(vim.split(section, '\n'), directory .. '/tmux.conf')
    local bashrc = table.concat(vim.fn.readfile(repo_home .. '/dot_bashrc'), '\n')
    local marker = assert(bashrc:match('(# WezTerm:.-)\neval "%$%(zoxide'))
    vim.fn.writefile(vim.split(marker .. '\nPS1="marker-test> "', '\n'), directory .. '/bashrc')

    -- A detached running program never prints a Bash prompt when a client attaches.
    tmux('-f', directory .. '/tmux.conf', 'new-session', '-d', '-s', 'review', 'sleep 300')
    terminal = vim.fn.jobstart(
      { 'bash', '--noprofile', '--rcfile', directory .. '/bashrc', '-i' },
      {
        pty = true,
        width = 80,
        height = 24,
        env = { TERM = 'xterm-256color' },
        on_stdout = function(_, data)
          output = output .. table.concat(data, '\n')
        end,
      }
    )
    assert.is_true(terminal > 0)
    wait_for('marker-test> ')
  end)

  after_each(function()
    if socket then
      vim.system({ 'tmux', '-S', socket, 'kill-server' }):wait()
    end
    if terminal and terminal > 0 then
      vim.fn.jobstop(terminal)
      vim.fn.jobwait({ terminal }, 1000)
    end
    if directory then
      vim.fn.delete(directory, 'rf')
    end
    if original_env then
      vim.env.TMUX = original_env.TMUX
      vim.env.TMUX_PANE = original_env.TMUX_PANE
    end
  end)

  it('marks reattached TUI sessions and clears after detach or final session exit', function()
    -- Reload must not append duplicate marker hooks.
    tmux('source-file', directory .. '/tmux.conf')
    local _, hook_count =
      tmux('show-hooks', '-g', 'client-attached'):gsub('SetUserVar=IS_TMUX=', '')
    assert.equals(1, hook_count)
    local function attach()
      output = ''
      vim.fn.chansend(terminal, 'tmux -S ' .. vim.fn.shellescape(socket) .. ' attach -t review\n')
      wait_for('\027]1337;SetUserVar=IS_TMUX=dHJ1ZQ==\007')
    end

    attach()
    output = ''
    tmux('detach-client')
    wait_for('marker-test> ')
    assert.is_truthy(output:find('\027]1337;SetUserVar=IS_TMUX=\007', 1, true))

    attach()
    output = ''
    tmux('kill-session', '-t', 'review')
    wait_for('marker-test> ')
    assert.is_truthy(output:find('\027]1337;SetUserVar=IS_TMUX=\007', 1, true))
  end)
end)
