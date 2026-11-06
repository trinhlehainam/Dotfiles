describe('first-install Tree-sitter injections', function()
  local modules =
    { 'configs.plugins.nvim-treesitter', 'configs.plugins.noice', 'configs.lsp', 'nvim-treesitter' }
  local saved, original, buf, buffers, available, complete, query_dir, notifications
  local function drain()
    vim.wait(20, function()
      return false
    end, 1)
  end
  before_each(function()
    saved = {}
    for _, name in ipairs(modules) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    original = {
      runtime_file = vim.api.nvim_get_runtime_file,
      has_language = vim._ts_has_language,
      start = vim.treesitter.start,
      runtimepath = vim.o.runtimepath,
      notify = vim.notify,
      buf = vim.api.nvim_get_current_buf(),
    }
    available, complete = false, nil
    query_dir, notifications = vim.fn.tempname(), {}
    vim.notify = function(message)
      notifications[#notifications + 1] = message
    end
    -- Use Neovim's bundled Markdown grammars; hide inline until the install callback.
    vim._ts_has_language = function(lang)
      if lang == 'markdown_inline' and not available then
        return false
      end
      return original.has_language(lang)
    end
    vim.api.nvim_get_runtime_file = function(pattern, all)
      if pattern == 'parser/markdown_inline.*' and not available then
        return {}
      end
      return original.runtime_file(pattern, all)
    end
    package.loaded['configs.plugins.noice'] = { parsers = {} }
    package.loaded['configs.lsp'] = { parsers = { 'markdown' } }
    package.loaded['nvim-treesitter'] = {
      get_available = function()
        return { 'markdown', 'markdown_inline' }
      end,
      install = function(parsers)
        assert.same({ 'markdown_inline' }, parsers)
        return {
          await = function(_, callback)
            complete = callback
          end,
        }
      end,
    }
    buf = vim.api.nvim_create_buf(false, false)
    buffers = { buf }
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'A **bold** word.' })
    require('configs.plugins.nvim-treesitter')
  end)
  after_each(function()
    collectgarbage('restart')
    vim.treesitter.start = original.start
    vim.notify = original.notify
    pcall(vim.api.nvim_del_augroup_by_name, 'dotfiles-treesitter')
    vim.api.nvim_set_current_buf(original.buf)
    for _, buffer in ipairs(buffers) do
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
    vim.api.nvim_get_runtime_file, vim._ts_has_language =
      original.runtime_file, original.has_language
    vim.fn.delete(query_dir, 'rf')
    vim.o.runtimepath = original.runtimepath
    vim.api.nvim_exec_autocmds('OptionSet', { pattern = 'runtimepath' })
    for _, name in ipairs(modules) do
      package.loaded[name] = saved[name]
    end
  end)

  it('refreshes a tree parsed by another plugin before its embedded grammar arrived', function()
    collectgarbage('collect')
    collectgarbage('stop') -- Keep the missing-parser memo alive until our completion hook clears it.
    local tree = assert(vim.treesitter.get_parser(buf, 'markdown'))
    tree:parse({ 0, 0, 1, 0 }) -- Same ranged parse used by treesitter-context.
    assert.is_nil(tree:children().markdown_inline)
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    vim.bo[buf].filetype = 'markdown'
    drain()
    assert.equals('function', type(complete))
    available = true
    complete()
    drain()
    tree:parse({ 0, 0, 1, 0 })
    assert.is_not_nil(tree:children().markdown_inline)
    assert.is_not_nil(vim.treesitter.highlighter.active[buf])
    assert.equals(tick, vim.api.nvim_buf_get_changedtick(buf))
  end)

  it('reuses active highlighters after an install and still shows new injections', function()
    collectgarbage('collect')
    collectgarbage('stop')
    local lua_buf = vim.api.nvim_create_buf(false, false)
    buffers[#buffers + 1] = lua_buf
    vim.bo[lua_buf].filetype = 'lua'
    vim.bo[buf].filetype = 'markdown'
    drain()
    -- A built-in ftplugin may start the host highlighter before its companion installs.
    vim.treesitter.start(buf, 'markdown')
    local markdown = assert(vim.treesitter.highlighter.active[buf])
    local lua = assert(vim.treesitter.highlighter.active[lua_buf])
    markdown.tree:parse(true)
    assert.is_nil(markdown.tree:children().markdown_inline)
    local starts = {}
    vim.treesitter.start = function(buffer, lang)
      starts[#starts + 1] = buffer
      return original.start(buffer, lang)
    end
    available = true
    complete()
    drain()
    assert.same({}, starts)
    assert.equals(markdown, vim.treesitter.highlighter.active[buf])
    assert.equals(lua, vim.treesitter.highlighter.active[lua_buf])
    markdown.tree:parse(true)
    local inline = vim.iter(vim.treesitter.get_captures_at_pos(buf, 0, 4)):any(function(capture)
      return capture.lang == 'markdown_inline'
    end)
    assert.is_true(inline)
  end)

  it('restarts highlighting when a filetype change selects another parser', function()
    -- C/Vim ftplugins neither start nor stop Tree-sitter, unlike Lua's.
    vim.bo[buf].filetype = 'c'
    assert.equals('c', vim.treesitter.highlighter.active[buf].tree:lang())
    vim.bo[buf].filetype = 'vim'
    assert.equals('vim', vim.treesitter.highlighter.active[buf].tree:lang())
  end)

  for _, kind in ipairs({ 'injections', 'highlights' }) do
    it('isolates invalid ' .. kind .. ' queries and recovers after repair', function()
      -- Real query files also exercise runtimepath cache invalidation after installation.
      for _, lang in ipairs({ 'c', 'markdown' }) do
        local dir = query_dir .. '/queries/' .. lang
        vim.fn.mkdir(dir, 'p')
        vim.fn.writefile({ '(dotfiles_invalid_node) @variable' }, dir .. '/' .. kind .. '.scm')
      end
      vim.opt.runtimepath:prepend(query_dir)
      -- Plenary runs before VimEnter, when setting an option does not emit OptionSet.
      vim.api.nvim_exec_autocmds('OptionSet', { pattern = 'runtimepath' })
      -- Catch-up visits an installed host, a waiting host, then a healthy buffer.
      vim.cmd('noautocmd setlocal filetype=c')
      local waiting = vim.api.nvim_create_buf(false, false)
      local healthy = vim.api.nvim_create_buf(false, false)
      buffers[#buffers + 1] = waiting
      buffers[#buffers + 1] = healthy
      vim.api.nvim_buf_call(waiting, function()
        vim.cmd('noautocmd setlocal filetype=markdown')
      end)
      vim.api.nvim_buf_call(healthy, function()
        vim.cmd('noautocmd setlocal filetype=vim')
      end)
      assert.is_true(vim.treesitter.language.add('c'))
      assert.is_true(vim.treesitter.language.add('markdown'))
      if kind == 'injections' then
        assert.is_nil(vim.treesitter.get_parser(buf, 'c'))
        assert.is_nil(vim.treesitter.get_parser(waiting, 'markdown'))
      else
        assert.is_not_nil(vim.treesitter.get_parser(buf, 'c'))
        assert.is_not_nil(vim.treesitter.get_parser(waiting, 'markdown'))
      end
      vim.api.nvim_exec_autocmds('FileType', { buffer = waiting, group = 'dotfiles-treesitter' })
      drain()
      available = true
      complete()
      drain()
      assert.is_nil(vim.treesitter.highlighter.active[buf])
      assert.is_nil(vim.treesitter.highlighter.active[waiting])
      assert.is_not_nil(vim.treesitter.highlighter.active[healthy])
      if kind == 'highlights' then
        assert.equals(2, #notifications)
        for _, message in ipairs(notifications) do
          assert.matches('Invalid node type', message, 1, true)
        end
      end

      vim.fn.delete(query_dir, 'rf')
      vim.o.runtimepath = original.runtimepath
      vim.api.nvim_exec_autocmds('OptionSet', { pattern = 'runtimepath' })
      for _, buffer in ipairs({ buf, waiting }) do
        vim.api.nvim_exec_autocmds('FileType', { buffer = buffer, group = 'dotfiles-treesitter' })
        assert.is_not_nil(vim.treesitter.highlighter.active[buffer])
      end
    end)
  end
end)
