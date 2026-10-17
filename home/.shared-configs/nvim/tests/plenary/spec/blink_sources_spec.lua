describe('Blink project completion', function()
  local modules = {
    'blink.cmp.config',
    'blink.cmp.sources.lib',
    'easy-dotnet.completion.blink',
    'easy-dotnet.rpc.rpc',
  }
  local saved, runtimepath, original_buf, buf, sources

  before_each(function()
    saved = {}
    for _, name in ipairs(modules) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end
    runtimepath = vim.o.runtimepath
    original_buf = vim.api.nvim_get_current_buf()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    local plugins = vim.fn.stdpath('data') .. '/lazy'
    vim.opt.runtimepath:append(vim.env.BLINK_CMP_DIR or (plugins .. '/blink.cmp'))
    vim.opt.runtimepath:append(vim.env.EASY_DOTNET_DIR or (plugins .. '/easy-dotnet.nvim'))
    require('blink.cmp.config').merge_with(require('plugins.blink')[2].opts)
    sources = require('blink.cmp.sources.lib')
  end)

  after_each(function()
    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.o.runtimepath = runtimepath
    for _, name in ipairs(modules) do
      package.loaded[name] = saved[name]
    end
  end)

  it('keeps the Dotnet source unloaded for unrelated files and ProjX projects', function()
    for _, name in ipairs({
      'notes.txt',
      'init.lua',
      'pom.xml',
      'Example.csproj',
      'Directory.Build.props',
      'Directory.Packages.props',
    }) do
      vim.api.nvim_buf_set_name(buf, name)
      vim.bo.filetype = name:match('%.props$') and 'xml' or vim.filetype.match({ filename = name })
      local ids = sources.get_enabled_provider_ids('default')
      assert.is_false(vim.tbl_contains(ids, 'easy-dotnet'))
      for _, id in ipairs({ 'lazydev', 'lsp', 'path', 'snippets' }) do
        assert.is_true(vim.tbl_contains(ids, id), name .. ' is missing ' .. id)
      end
    end
    assert.is_nil(package.loaded['easy-dotnet.completion.blink'])
  end)

  -- Exercise the real Blink provider with only the NuGet transport replaced.
  ---@param filename string
  ---@param line string
  ---@param nuget table
  ---@return blink.cmp.CompletionItem[]
  local function complete_project(filename, line, nuget)
    vim.api.nvim_buf_set_name(buf, filename)
    vim.bo.filetype = vim.filetype.match({ filename = filename })
    assert.is_true(vim.tbl_contains(sources.get_enabled_provider_ids('default'), 'easy-dotnet'))
    package.loaded['easy-dotnet.rpc.rpc'] = {
      global_rpc_client = {
        initialize = function(_, callback)
          callback()
        end,
        nuget = nuget,
      },
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line .. '" />' })
    vim.api.nvim_win_set_cursor(0, { 1, #line })
    local items
    sources.get_provider_by_id('easy-dotnet'):get_completions({
      id = 1,
      bufnr = buf,
      line = line,
      cursor = { 1, #line },
      bounds = { start_col = 1, length = #line },
      trigger = { initial_kind = 'manual' },
    }, function(result)
      items = result
    end)
    return items
  end

  for _, filename in ipairs({ 'Example.fsproj', 'Example.vbproj' }) do
    it('preserves default sources with Dotnet completion in ' .. filename, function()
      vim.api.nvim_buf_set_name(buf, filename)
      vim.bo.filetype = vim.filetype.match({ filename = filename })
      assert.equals('xml', vim.bo.filetype)
      local ids = sources.get_enabled_provider_ids('default')
      for _, id in ipairs({ 'easy-dotnet', 'lazydev', 'lsp', 'path', 'snippets' }) do
        assert.is_true(vim.tbl_contains(ids, id), filename .. ' is missing ' .. id)
      end
      assert.is_true(sources.get_provider_by_id('easy-dotnet'):enabled())
    end)

    it('returns NuGet package names in ' .. filename .. ' detected as XML', function()
      local items = complete_project(filename, '<PackageReference Include="Newt', {
        nuget_search = function(_, term, _, callback)
          assert.equals('Newt', term)
          callback({ { id = 'Newtonsoft.Json', source = 'nuget.org' } })
          return { cancel = function() end }
        end,
      })
      assert.equals('Newtonsoft.Json', items[1].insertText)
      assert.equals('easy-dotnet', items[1].source_id)
    end)

    it('returns NuGet versions in ' .. filename .. ' detected as XML', function()
      local items =
        complete_project(filename, '<PackageReference Include="Newtonsoft.Json" Version="13.', {
          nuget_get_package_versions = function(_, name, _, _, callback)
            assert.equals('Newtonsoft.Json', name)
            callback({ '13.0.3' })
            return { cancel = function() end }
          end,
        })
      assert.equals('13.0.3', items[1].insertText)
      assert.equals('easy-dotnet', items[1].source_id)
    end)
  end
end)
