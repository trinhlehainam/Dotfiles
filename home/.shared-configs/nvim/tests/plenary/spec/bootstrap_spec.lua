describe('Neovim bootstrap', function()
  local original_lazy
  local original_project
  local original_minimal

  before_each(function()
    original_lazy = package.loaded['configs.lazy']
    original_project = package.loaded['configs.project']
    original_minimal = vim.g.dotfiles_minimal
  end)

  after_each(function()
    package.loaded['configs.lazy'] = original_lazy
    package.loaded['configs.project'] = original_project
    vim.g.dotfiles_minimal = original_minimal
  end)

  it('accepts the minimal-editor command with whitespace-only argument splitting', function()
    -- Smoke-test the invocation syntax; scripts/agent-prompt-editor.test.ts checks the wrappers.
    local args = vim.split('nvim --cmd let[g:dotfiles_minimal]=[v:true]', '%s+')
    assert.equals(3, #args)
    assert.equals('nvim', args[1])
    assert.equals('--cmd', args[2])
    vim.cmd(args[3])
    assert.is_true(vim.g.dotfiles_minimal)
  end)

  it('keeps prompt editing usable without loading plugins or project tooling', function()
    vim.g.dotfiles_minimal = true
    package.loaded['configs.lazy'] = {
      setup = function()
        error('Minimal editing must not bootstrap the plugin manager')
      end,
    }
    package.loaded['configs.project'] = {
      setup = function()
        error('Minimal editing must not load project tooling')
      end,
    }

    require('configs.bootstrap').setup()
    require('configs.bootstrap').setup()

    assert.is_true(vim.o.number)
    assert.is_true(vim.o.undofile)
    assert.is_true(vim.o.showmode)
    assert.equals('<Esc>', vim.fn.maparg('jk', 'i'))
    assert.same({}, vim.fn.maparg('s', 'n', false, true))
    assert.same({}, vim.fn.maparg('S', 'n', false, true))
  end)

  it('starts the full config when minimal editing is not requested', function()
    vim.g.dotfiles_minimal = nil
    local lazy_opts
    local project_loaded = false
    package.loaded['configs.lazy'] = {
      setup = function(opts)
        lazy_opts = opts
      end,
    }
    package.loaded['configs.project'] = {
      setup = function()
        project_loaded = true
      end,
    }
    local opts = { config = { install = { missing = false } } }

    require('configs.bootstrap').setup({ lazy = opts })

    assert.equals(opts, lazy_opts)
    assert.is_true(project_loaded)
  end)
end)
