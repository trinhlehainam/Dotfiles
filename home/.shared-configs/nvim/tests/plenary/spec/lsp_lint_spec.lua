describe('LSP registry lint policy', function()
  local module_names = { 'configs.plugins.nvim-lint', 'configs.lsp', 'configs.project', 'lint' }
  local command_names = { 'Lint', 'LintEnable', 'LintDisable', 'LintToggle' }
  local original_modules
  local original_buf
  local bufnr
  local lint_runs
  local project_lint_on_save

  before_each(function()
    original_modules = {}
    lint_runs = {}
    project_lint_on_save = nil
    for _, name in ipairs(module_names) do
      original_modules[name] = package.loaded[name]
      package.loaded[name] = nil
    end

    original_buf = vim.api.nvim_get_current_buf()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].filetype = 'php.blade'
    package.loaded['configs.lsp'] = {
      linters = { php = { 'phpstan' } },
      lint_on_save = { php = false },
    }
    package.loaded['configs.project'] = {
      get_project_linters = function()
        return {}
      end,
      get_tooling_lint_on_save = function()
        return project_lint_on_save
      end,
    }
    package.loaded['lint'] = {
      try_lint = function(linters)
        lint_runs[#lint_runs + 1] = {
          bufnr = vim.api.nvim_get_current_buf(),
          linters = vim.deepcopy(linters),
        }
      end,
    }
    require('configs.plugins.nvim-lint')
  end)

  after_each(function()
    vim.api.nvim_del_augroup_by_name('nvim-lint')
    for _, name in ipairs(command_names) do
      vim.api.nvim_del_user_command(name)
    end
    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    for _, name in ipairs(module_names) do
      package.loaded[name] = original_modules[name]
    end
  end)

  it('preserves a false save policy inherited by a compound filetype', function()
    vim.api.nvim_exec_autocmds('BufWritePost', { group = 'nvim-lint', buffer = bufnr })

    assert.same({}, lint_runs)
  end)

  it('allows manual linting when the inherited save policy is false', function()
    vim.api.nvim_set_current_buf(bufnr)
    vim.cmd.Lint()

    assert.same({ { bufnr = bufnr, linters = { 'phpstan' } } }, lint_runs)
  end)

  it('lets project policy enable save linting for the written buffer', function()
    project_lint_on_save = true
    vim.api.nvim_exec_autocmds('BufWritePost', { group = 'nvim-lint', buffer = bufnr })

    assert.same({ { bufnr = bufnr, linters = { 'phpstan' } } }, lint_runs)
    assert.equals(original_buf, vim.api.nvim_get_current_buf())
  end)
end)
