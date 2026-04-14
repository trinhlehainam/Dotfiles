return {
  'NickvanDyke/opencode.nvim',
  dependencies = { 'folke/snacks.nvim' },
  config = function()
    -- https://github.com/nickjvandyke/opencode.nvim?tab=readme-ov-file#customization
    -- Run OpenCode inside a hardened Docker container
    local function shell_arg(value)
      return vim.fn.shellescape(tostring(value))
    end

    local function bind_mount(src, dst, readonly)
      return shell_arg(('type=bind,src=%s,dst=%s%s'):format(src, dst, readonly and ',ro' or ''))
    end

    local function docker_env(name, value)
      if value == nil or value == '' then
        return ''
      end

      return ' --env ' .. shell_arg(('%s=%s'):format(name, value))
    end

    local function opencode_port()
      local current = vim.g.opencode_container_port
      if type(current) == 'number' then
        return current
      end

      local uv = vim.uv or vim.loop
      local tcp = uv.new_tcp()
      local ok = tcp and pcall(function()
        assert(tcp:bind('127.0.0.1', 0))
      end)

      if ok and tcp then
        local sockname = assert(tcp:getsockname())
        tcp:close()
        vim.g.opencode_container_port = sockname.port
        return sockname.port
      end

      if tcp then
        tcp:close()
      end

      vim.g.opencode_container_port = 40000 + (vim.fn.getpid() % 20000)
      return vim.g.opencode_container_port
    end

    local uid = vim.fn.systemlist('id -u')[1] or '1000'
    local gid = vim.fn.systemlist('id -g')[1] or '1000'
    local cwd = vim.fn.getcwd(-1, -1)
    local config_src = vim.fn.expand('~/.config/opencode')
    local data_src = vim.fn.expand('~/.local/share/opencode')
    local port = opencode_port()
    local event_connect_max_attempts = 180
    local event_connect_interval_ms = 1000

    vim.fn.mkdir(config_src, 'p')
    vim.fn.mkdir(data_src, 'p')

    -- Config + auth: read-only bind mounts at staging paths, copied to writable
    -- tmpfs so OpenCode can write runtime state without modifying host files.
    -- The full data dir can contain large session snapshots, so only auth.json
    -- is copied from host state.
    local init_script = string.format(
      'set -eu'
        .. ' && mkdir -p /opencode-config/opencode /opencode-data/opencode'
        .. ' && cp -R /opencode-config-ro/. /opencode-config/opencode/'
        .. ' && if [ -f /opencode-data-ro/auth.json ]; then cp /opencode-data-ro/auth.json /opencode-data/opencode/auth.json; fi'
        .. ' && exec opencode --hostname 0.0.0.0 --port %d',
      port
    )
    local opencode_cmd = string.format(
      'docker run --rm -it --pull always --init'
        .. ' --user %s:%s'
        .. ' --mount %s'
        .. ' --mount %s'
        .. ' --mount %s'
        .. ' --tmpfs /opencode-config:rw,exec,nosuid,size=100m'
        .. ' --tmpfs /opencode-data:rw,exec,nosuid,size=1g'
        .. ' --workdir %s'
        .. ' --read-only'
        .. ' --cap-drop ALL'
        .. ' --security-opt no-new-privileges'
        .. ' --tmpfs /tmp:rw,exec,nosuid,size=1g'
        .. ' --publish %s'
        .. ' --env HOME=/tmp/opencode-home'
        .. ' --env XDG_CONFIG_HOME=/opencode-config'
        .. ' --env XDG_DATA_HOME=/opencode-data'
        .. ' --env OPENCODE_DISABLE_AUTOUPDATE=1'
        .. ' --env OPENCODE_NOTIFY_TRANSPORT=host-nvim'
        .. ' --env OPENCODE_AGENT_NOTIFY_DISABLED=1'
        .. '%s'
        .. '%s'
        .. ' --entrypoint sh'
        .. ' ghcr.io/anomalyco/opencode:latest'
        .. ' -c %s',
      uid,
      gid,
      bind_mount(cwd, cwd, false),
      bind_mount(config_src, '/opencode-config-ro', true),
      bind_mount(data_src, '/opencode-data-ro', true),
      shell_arg(cwd),
      shell_arg(('127.0.0.1:%d:%d'):format(port, port)),
      docker_env('TERM', vim.env.TERM or 'xterm-256color'),
      docker_env('COLORTERM', vim.env.COLORTERM or 'truecolor'),
      shell_arg(init_script)
    )

    local event_connecting = false
    local function connect_opencode_events()
      if event_connecting then
        return
      end

      event_connecting = true
      local attempts = 0
      local function try_connect()
        attempts = attempts + 1

        local connected_server = require('opencode.events').connected_server
        if connected_server and connected_server.port == port then
          event_connecting = false
          return
        end

        require('opencode.server')
          .new(port)
          :next(function(server)
            require('opencode.events').connect(server)
            event_connecting = false
          end)
          :catch(function()
            if attempts >= event_connect_max_attempts then
              event_connecting = false
              vim.notify(
                'OpenCode event bridge did not connect; host notifications are disabled for this container session',
                vim.log.levels.WARN,
                { title = 'opencode' }
              )
              return
            end

            vim.defer_fn(try_connect, event_connect_interval_ms)
          end)
      end

      vim.defer_fn(try_connect, event_connect_interval_ms)
    end

    ---@type snacks.terminal.Opts
    local snacks_terminal_opts = {
      win = {
        bo = {
          filetype = 'opencode_terminal',
        },
        position = 'right',
        enter = true,
        width = 0.4,
        on_win = function(win)
          -- Set up keymaps and cleanup for an arbitrary terminal
          require('opencode.terminal').setup(win.win)
          connect_opencode_events()
        end,
      },
    }
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      server = {
        port = port,
        start = function()
          require('snacks.terminal').open(opencode_cmd, snacks_terminal_opts)
          connect_opencode_events()
        end,
        stop = function()
          require('snacks.terminal').get(opencode_cmd, snacks_terminal_opts):close()
        end,
        toggle = function()
          require('snacks.terminal').toggle(opencode_cmd, snacks_terminal_opts)
          connect_opencode_events()
        end,
      },
    }

    require('configs.plugins.opencode_notify').setup()

    -- Required for `opts.events.reload`.
    vim.o.autoread = true

    vim.keymap.set({ 'n', 'x' }, '<leader>oa', function()
      require('opencode').ask('@this: ', { submit = true })
    end, { desc = 'Ask opencode' })
    vim.keymap.set({ 'n', 'x' }, '<leader>ox', function()
      require('opencode').select()
    end, { desc = 'Execute opencode action…' })
    vim.keymap.set({ 'n', 'x' }, '<leader>os', function()
      require('opencode').prompt('@this')
    end, { desc = 'Send to opencode' })
    vim.keymap.set({ 'n', 'x' }, '<leader>ob', function()
      require('opencode').prompt('@buffer')
    end, { desc = 'Add current buffer' })
    vim.keymap.set({ 'n', 't' }, '<leader>oc', function()
      require('opencode').toggle()
    end, { desc = 'Toggle opencode' })

    -- Passthrough <C-A-d> and <C-A-u> to OpenCode terminal
    -- These are used for half-page scrolling in OpenCode
    -- Must use nvim_chan_send() to write directly to terminal PTY,
    -- bypassing Neovim's input processing
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'opencode_terminal',
      callback = function(args)
        local bufnr = args.buf
        local opts = { buffer = bufnr, silent = true }

        local function send_to_terminal(escape_seq)
          local chan = vim.bo[bufnr].channel
          if chan then
            vim.api.nvim_chan_send(chan, escape_seq)
          end
        end

        -- ESC + Ctrl-D (0x1b 0x04) for Ctrl-Alt-D
        vim.keymap.set('t', '<C-A-d>', function()
          send_to_terminal('\x1b\x04')
        end, opts)

        -- ESC + Ctrl-U (0x1b 0x15) for Ctrl-Alt-U
        vim.keymap.set('t', '<C-A-u>', function()
          send_to_terminal('\x1b\x15')
        end, opts)

        -- Ctrl-W (0x17) for delete word backward
        -- Bypasses Neovim's window command prefix
        vim.keymap.set('t', '<C-w>', function()
          send_to_terminal('\x17')
        end, opts)
      end,
    })
  end,
}
