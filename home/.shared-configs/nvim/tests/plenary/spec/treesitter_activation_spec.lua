describe('on-demand Tree-sitter', function()
  local modules =
    { 'configs.plugins.nvim-treesitter', 'configs.plugins.noice', 'configs.lsp', 'nvim-treesitter' }
  local saved, original, buffers, installed, batches, started, warnings
  local aliases =
    { sh = 'bash', typescriptreact = 'tsx', cs = 'c_sharp', ['yaml.ansible'] = 'yaml' }
  local supported = {
    'bash',
    'tsx',
    'c_sharp',
    'yaml',
    'toml',
    'vue',
    'php',
    'html',
    'javascript',
    'typescript',
    'css',
    'scss',
    'phpdoc',
    'jsdoc',
    'regex',
    'lua',
    'markdown',
    'markdown_inline',
  }
  local function drain()
    vim.wait(20, function()
      return false
    end, 1)
  end
  local function setup()
    package.loaded['configs.plugins.nvim-treesitter'] = nil
    require('configs.plugins.nvim-treesitter')
    drain()
  end
  local function open(filetype, buftype)
    local buf = vim.api.nvim_create_buf(false, false)
    buffers[#buffers + 1] = buf
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].buftype = buftype or ''
    vim.bo[buf].filetype = filetype
    return buf
  end
  local function finish(index, failed)
    local batch = batches[index]
    for _, parser in ipairs(batch.parsers) do
      if not vim.tbl_contains(failed or {}, parser) then
        installed[parser] = true
      end
    end
    batch.callback()
    drain()
  end
  local function has_started(buf, parser)
    return vim.tbl_contains(started, function(entry)
      return entry.buf == buf and entry.parser == parser
    end, { predicate = true })
  end

  before_each(function()
    saved, buffers, installed, batches, started, warnings = {}, {}, {}, {}, {}, {}
    for _, name in ipairs(modules) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    original = {
      start = vim.treesitter.start,
      get_parser = vim.treesitter.get_parser,
      add = vim.treesitter.language.add,
      get_lang = vim.treesitter.language.get_lang,
      notify = vim.notify,
      buf = vim.api.nvim_get_current_buf(),
    }
    vim.treesitter.language.get_lang = function(ft)
      return aliases[ft] or ft
    end
    vim.treesitter.language.add = function(parser)
      return installed[parser]
    end
    vim.treesitter.start = function(buf, parser)
      started[#started + 1] = { buf = buf, parser = parser }
    end
    vim.treesitter.get_parser = function()
      return { invalidate = function() end }
    end
    vim.notify = function(message)
      warnings[#warnings + 1] = message
    end
    package.loaded['nvim-treesitter'] = {
      get_available = function()
        return supported
      end,
      install = function(parsers)
        local batch = { parsers = parsers }
        batches[#batches + 1] = batch
        return {
          await = function(_, callback)
            batch.callback = callback
          end,
        }
      end,
    }
    package.loaded['configs.plugins.noice'] = { parsers = {} }
    package.loaded['configs.lsp'] =
      { parsers = { 'bash', 'tsx', 'c_sharp', 'yaml', 'vue', 'php', 'html' } }
  end)
  after_each(function()
    pcall(vim.api.nvim_del_augroup_by_name, 'dotfiles-treesitter')
    vim.api.nvim_set_current_buf(original.buf)
    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    drain()
    vim.treesitter.start, vim.treesitter.language.add = original.start, original.add
    vim.treesitter.get_parser = original.get_parser
    vim.treesitter.language.get_lang, vim.notify = original.get_lang, original.notify
    for _, name in ipairs(modules) do
      package.loaded[name] = saved[name]
    end
  end)

  it('does not install the language allowlist at startup', function()
    setup()
    assert.same({}, batches)
  end)
  it('installs only missing parsers used by the Noice UI at startup', function()
    package.loaded['configs.plugins.noice'].parsers = { 'lua', 'regex' }
    installed.lua = true
    setup()
    assert.same({ 'regex' }, batches[1].parsers)
  end)
  for ft, parser in pairs(aliases) do
    it('resolves the ' .. ft .. ' alias and starts installed highlighting', function()
      for _, name in ipairs(supported) do
        installed[name] = true
      end
      setup()
      local buf = open(ft)
      assert.is_true(has_started(buf, parser))
      assert.same({}, batches)
    end)
  end
  it('installs once for two buffers and starts both when compilation finishes', function()
    setup()
    local first, second = open('sh'), open('sh')
    vim.api.nvim_exec_autocmds('FileType', { buffer = first })
    drain()
    assert.equals(1, #batches)
    assert.same({ 'bash' }, batches[1].parsers)
    assert.same({}, started)
    finish(1)
    assert.is_true(has_started(first, 'bash'))
    assert.is_true(has_started(second, 'bash'))
  end)
  it('catches buffers opened before plugin setup', function()
    local buf = open('cs')
    setup()
    assert.same({ 'c_sharp' }, batches[1].parsers)
    finish(1)
    assert.is_true(has_started(buf, 'c_sharp'))
  end)
  it('ignores closed, unloaded and changed-filetype buffers after installation', function()
    setup()
    local closed, unloaded, changed = open('sh'), open('sh'), open('sh')
    drain()
    vim.api.nvim_buf_delete(closed, { force = true })
    vim.api.nvim_buf_delete(unloaded, { unload = true })
    vim.bo[changed].filetype = 'text'
    finish(1)
    assert.same({}, started)
  end)
  it('highlights special buffers only with already installed parsers', function()
    setup()
    open('sh', 'nofile')
    drain()
    assert.same({}, batches)
    installed.bash = true
    local buf = open('sh', 'nofile')
    assert.is_true(has_started(buf, 'bash'))
  end)
  it('leaves unsupported and unconfigured filetypes alone', function()
    installed.rust = true
    setup()
    open('rust')
    open('nonexistent')
    drain()
    assert.same({}, batches)
    assert.same({}, started)
  end)
  it('installs PHP injection parsers even if the host parser already exists', function()
    installed.php = true
    setup()
    local buf = open('php')
    drain()
    assert.same({ 'css', 'html', 'javascript', 'jsdoc', 'phpdoc', 'regex' }, batches[1].parsers)
    finish(1)
    assert.is_true(has_started(buf, 'php'))
  end)
  it('includes Vue script/style grammars without installing unrelated languages', function()
    setup()
    local buf = open('vue')
    drain()
    assert.same(
      { 'css', 'javascript', 'jsdoc', 'regex', 'scss', 'tsx', 'typescript', 'vue' },
      batches[1].parsers
    )
    finish(1)
    assert.is_true(has_started(buf, 'vue'))
  end)
  it('installs Markdown front matter and HTML grammars without arbitrary code fences', function()
    installed.markdown, installed.markdown_inline = true, true
    setup()
    local buf = open('markdown')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '```python', 'print(1)', '```' })
    drain()
    assert.same({ 'html', 'toml', 'yaml' }, batches[1].parsers)
    finish(1)
    assert.is_true(has_started(buf, 'markdown'))
    assert.equals(1, #batches)
  end)
  it('queues new languages while a batch runs, avoiding overlapping dependency installs', function()
    setup()
    open('sh')
    drain()
    local buf = open('cs')
    drain()
    assert.equals(1, #batches)
    finish(1)
    assert.equals(2, #batches)
    assert.same({ 'c_sharp' }, batches[2].parsers)
    finish(2)
    assert.is_true(has_started(buf, 'c_sharp'))
  end)
  it('reports a failed parser once and accepts a later manual install', function()
    setup()
    local buf = open('sh')
    drain()
    finish(1, { 'bash' })
    vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
    drain()
    assert.equals(1, #batches)
    assert.equals(1, #warnings)
    assert.same({}, started)
    installed.bash = true
    vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
    assert.is_true(has_started(buf, 'bash'))
  end)
  it('still highlights the host when an injection parser fails', function()
    setup()
    local buf = open('php')
    drain()
    finish(1, { 'phpdoc' })
    assert.is_true(has_started(buf, 'php'))
    assert.equals(1, #warnings)
    assert.equals(1, #batches)
  end)

  it('groups failed parsers into one warning with a batch retry command', function()
    setup()
    local buf = open('php')
    drain()
    finish(1, { 'phpdoc', 'regex' })
    assert.is_true(has_started(buf, 'php'))
    assert.equals(1, #warnings)
    assert.matches(':TSInstall phpdoc regex', warnings[1], 1, true)
  end)
end)
