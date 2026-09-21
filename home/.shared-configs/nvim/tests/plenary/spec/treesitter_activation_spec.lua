describe('Tree-sitter highlighting activation', function()
  local module_names = {
    'configs.plugins.nvim-treesitter',
    'configs.plugins.noice',
    'configs.lsp',
    'nvim-treesitter',
  }
  local mappings = { sh = 'bash', typescriptreact = 'tsx', cs = 'c_sharp' }
  local original_modules
  local original
  local buffers
  local started
  local installed
  local available
  local existing_autocmds

  local function open_filetype(filetype)
    local bufnr = vim.api.nvim_create_buf(false, true)
    buffers[#buffers + 1] = bufnr
    vim.api.nvim_set_current_buf(bufnr)
    vim.bo[bufnr].filetype = filetype
    return bufnr
  end

  before_each(function()
    buffers = {}
    started = {}
    installed = {}
    existing_autocmds = {}
    original_modules = {}
    for _, name in ipairs(module_names) do
      original_modules[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    original = {
      start = vim.treesitter.start,
      add = vim.treesitter.language.add,
      current_buf = vim.api.nvim_get_current_buf(),
      mappings = {},
      errmsg = vim.v.errmsg,
    }
    for filetype, language in pairs(mappings) do
      original.mappings[filetype] = vim.treesitter.language.get_lang(filetype)
      vim.treesitter.language.register(language, filetype)
    end
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = 'FileType' })) do
      if autocmd.id then
        existing_autocmds[autocmd.id] = true
      end
    end

    available = { bash = true, tsx = true, c_sharp = true, yaml = true, rust = true }
    vim.treesitter.language.add = function(language)
      if available[language] then
        return true
      end
      return nil, 'No parser for language ' .. language
    end
    vim.treesitter.start = function(bufnr, language)
      if bufnr == nil or bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
      end
      language = language or vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
      assert(available[language], 'No parser for language ' .. language)
      started[#started + 1] = { bufnr = bufnr, language = language }
    end
    package.loaded['nvim-treesitter'] = {
      install = function(parsers)
        installed = parsers
      end,
    }
    package.loaded['configs.plugins.noice'] = { parsers = {} }
    local parsers = { 'bash', 'tsx', 'c_sharp', 'yaml' }
    package.loaded['configs.lsp'] = {
      parsers = parsers,
    }
    require('configs.plugins.nvim-treesitter')
    vim.v.errmsg = ''
  end)

  after_each(function()
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = 'FileType' })) do
      if autocmd.id and not existing_autocmds[autocmd.id] then
        pcall(vim.api.nvim_del_autocmd, autocmd.id)
      end
    end
    vim.api.nvim_set_current_buf(original.current_buf)
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    vim.treesitter.start = original.start
    vim.treesitter.language.add = original.add
    vim.v.errmsg = original.errmsg
    for filetype, language in pairs(original.mappings) do
      vim.treesitter.language.register(language, filetype)
    end
    for _, name in ipairs(module_names) do
      package.loaded[name] = original_modules[name]
    end
  end)

  for _, case in ipairs({
    { filetype = 'sh', parser = 'bash' },
    { filetype = 'typescriptreact', parser = 'tsx' },
    { filetype = 'cs', parser = 'c_sharp' },
    { filetype = 'yaml.ansible', parser = 'yaml' },
  }) do
    it('starts ' .. case.parser .. ' highlighting for ' .. case.filetype, function()
      assert.is_true(vim.list_contains(installed, case.parser))
      local bufnr = open_filetype(case.filetype)

      assert.same({ { bufnr = bufnr, language = case.parser } }, started)
    end)
  end

  it('skips configured parsers that are not installed yet', function()
    assert.is_true(vim.list_contains(installed, 'bash'))
    available.bash = nil
    open_filetype('bash')

    assert.equals('', vim.v.errmsg)
    assert.same({}, started)
  end)

  it('leaves unrelated filetypes inactive even when their parser is installed', function()
    assert.is_false(vim.list_contains(installed, 'rust'))
    open_filetype('rust')

    assert.same({}, started)
  end)
end)
