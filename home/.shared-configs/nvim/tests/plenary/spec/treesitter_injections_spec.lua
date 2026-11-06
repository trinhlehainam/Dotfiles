describe('first-install Tree-sitter injections', function()
  local modules =
    { 'configs.plugins.nvim-treesitter', 'configs.plugins.noice', 'configs.lsp', 'nvim-treesitter' }
  local saved, original, buf, available, complete
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
      buf = vim.api.nvim_get_current_buf(),
    }
    available, complete = false, nil
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
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'A **bold** word.' })
    require('configs.plugins.nvim-treesitter')
  end)
  after_each(function()
    collectgarbage('restart')
    pcall(vim.api.nvim_del_augroup_by_name, 'dotfiles-treesitter')
    vim.api.nvim_set_current_buf(original.buf)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.api.nvim_get_runtime_file, vim._ts_has_language =
      original.runtime_file, original.has_language
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
end)
