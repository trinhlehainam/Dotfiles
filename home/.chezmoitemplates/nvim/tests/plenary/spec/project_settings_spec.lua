local h = require('project_settings_harness')

h.setup()

local function write_vscode_settings(path, content)
  h.write_file(path, content)
end

describe('project settings regression', function()
  local base

  before_each(function()
    h.reset_to_scratch()
    base = h.new_base()
  end)

  it('keeps project indentation authoritative after BufReadPost changes', function()
    local root = h.mktemp_root(base, 'guess-indent-root')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['[php]'] = {
        ['editor.insertSpaces'] = true,
        ['editor.tabSize'] = 4,
        ['editor.detectIndentation'] = false,
      },
    })

    local file = h.join(root, 'sample.php')
    h.write_file(file, "<?php\n\tif (true) {\n\t\techo 'tabs';\n\t}\n")

    local bufnr = h.edit(file)
    local expected = {
      expandtab = true,
      tabstop = 4,
      shiftwidth = 4,
      softtabstop = 4,
    }

    h.wait_for_filetype(bufnr, 'php', 'php filetype should be detected')
    h.wait_for_indent(
      bufnr,
      expected,
      'project settings should win after BufReadPost indentation changes'
    )

    assert.same(expected, h.read_indent(bufnr))
  end)

  it('applies filetype settings when a new root is opened after startup', function()
    local root = h.mktemp_root(base, 'later-root')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['[php]'] = {
        ['editor.insertSpaces'] = false,
        ['editor.tabSize'] = 7,
        ['editor.detectIndentation'] = false,
      },
    })

    local file = h.join(root, 'later.php')
    h.write_file(file, "<?php\n  echo 'spaces';\n")

    local bufnr = h.edit(file)
    local expected = {
      expandtab = false,
      tabstop = 7,
      shiftwidth = 7,
      softtabstop = 7,
    }

    h.wait_for_filetype(bufnr, 'php', 'later-opened root should still detect php')
    h.wait_for_indent(
      bufnr,
      expected,
      'later-opened root should apply project indentation on first open'
    )

    assert.same(expected, h.read_indent(bufnr))
  end)

  it('clears removed project-managed file associations on reload', function()
    local root = h.mktemp_root(base, 'association-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    h.write_json(settings, {
      ['files.associations'] = {
        ['*.templ'] = 'php',
      },
    })

    local file = h.join(root, 'sample.templ')
    h.write_file(file, '<div>value</div>\n')

    local bufnr = h.edit(file)
    h.wait_for_filetype(bufnr, 'php', 'project file association should set filetype')

    h.write_json(settings, {})
    h.reload()

    h.wait_for_filetype(bufnr, '', 'reload should clear removed project-managed filetype')
    assert.equals('', vim.bo[bufnr].filetype)
  end)

  it('restores default indentation when project overrides are removed on reload', function()
    local defaults = h.php_defaults()
    local root = h.mktemp_root(base, 'indent-reset-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    h.write_json(settings, {
      ['[php]'] = {
        ['editor.insertSpaces'] = true,
        ['editor.tabSize'] = 8,
        ['editor.detectIndentation'] = false,
      },
    })

    local file = h.join(root, 'reset.php')
    h.write_file(file, '<?php\n\treturn 1;\n')

    local bufnr = h.edit(file)
    local overridden = {
      expandtab = true,
      tabstop = 8,
      shiftwidth = 8,
      softtabstop = 8,
    }

    h.wait_for_indent(
      bufnr,
      overridden,
      'project-local indent override should apply before reload reset'
    )
    assert.same(overridden, h.read_indent(bufnr))

    h.write_json(settings, {})
    h.reload()

    h.wait_for_indent(
      bufnr,
      defaults,
      'reload should restore default php indentation after removing project override'
    )
    assert.same(defaults, h.read_indent(bufnr))
  end)

  it('keeps unmanaged manual filetypes on reload', function()
    local root = h.mktemp_root(base, 'manual-filetype-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    h.write_json(settings, {})

    local file = h.join(root, 'manual.templ')
    h.write_file(file, '<div>manual</div>\n')

    local bufnr = h.edit(file)
    vim.bo[bufnr].filetype = 'html'

    h.write_json(settings, {
      ['[lua]'] = {
        ['editor.tabSize'] = 2,
      },
    })
    h.reload()

    h.wait_for_filetype(bufnr, 'html', 'reload should not clear unmanaged manual filetype')
    assert.equals('html', vim.bo[bufnr].filetype)
  end)

  it('keeps unmanaged manual indentation on reload', function()
    local root = h.mktemp_root(base, 'manual-indent-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    h.write_json(settings, {})

    local file = h.join(root, 'manual.php')
    h.write_file(file, "<?php\n  echo 'manual';\n")

    local bufnr = h.edit(file)
    h.wait_for_filetype(
      bufnr,
      'php',
      'php filetype should be detected before manual indent override'
    )

    local manual = {
      expandtab = false,
      tabstop = 3,
      shiftwidth = 3,
      softtabstop = 3,
    }

    vim.bo[bufnr].expandtab = manual.expandtab
    vim.bo[bufnr].tabstop = manual.tabstop
    vim.bo[bufnr].shiftwidth = manual.shiftwidth
    vim.bo[bufnr].softtabstop = manual.softtabstop

    h.write_json(settings, {
      ['[lua]'] = {
        ['editor.insertSpaces'] = false,
      },
    })
    h.reload()

    assert.same(manual, h.read_indent(bufnr))
  end)

  it('parses JSONC line comments for project file associations', function()
    local root = h.mktemp_root(base, 'jsonc-line-comments-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    write_vscode_settings(
      settings,
      [[
{
  // Project-local association should survive JSONC comments.
  "files.associations": {
    "*.foojsonc": "php"
  }
}
]]
    )

    local file = h.join(root, 'sample.foojsonc')
    h.write_file(file, "<?php\n  echo 'jsonc';\n")

    local bufnr = h.edit(file)
    h.wait_for_filetype(bufnr, 'php', 'JSONC comments should not disable project file associations')
    assert.equals('php', vim.bo[bufnr].filetype)
  end)

  it('parses JSONC block comments for per-filetype editor settings', function()
    local root = h.mktemp_root(base, 'jsonc-block-comments-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    write_vscode_settings(
      settings,
      [[
{
  /* Project-local indentation should survive block comments. */
  "[php]": {
    "editor.insertSpaces": false,
    "editor.tabSize": 6,
    "editor.detectIndentation": false
  }
}
]]
    )

    local file = h.join(root, 'sample.php')
    h.write_file(file, "<?php\n    echo 'jsonc';\n")

    local bufnr = h.edit(file)
    local expected = {
      expandtab = false,
      tabstop = 6,
      shiftwidth = 6,
      softtabstop = 6,
    }

    h.wait_for_filetype(bufnr, 'php', 'php filetype should still be detected')
    h.wait_for_indent(bufnr, expected, 'JSONC block comments should not disable editor settings')
    assert.same(expected, h.read_indent(bufnr))
  end)

  it('parses JSONC trailing commas for file associations and editor settings', function()
    local root = h.mktemp_root(base, 'jsonc-trailing-commas-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    write_vscode_settings(
      settings,
      [[
{
  "files.associations": {
    "*.trailjsonc": "php",
  },
  "[php]": {
    "editor.insertSpaces": true,
    "editor.tabSize": 5,
    "editor.detectIndentation": false,
  },
}
]]
    )

    local file = h.join(root, 'sample.trailjsonc')
    h.write_file(file, "<?php\n\techo 'trail';\n")

    local bufnr = h.edit(file)
    local expected = {
      expandtab = true,
      tabstop = 5,
      shiftwidth = 5,
      softtabstop = 5,
    }

    h.wait_for_filetype(bufnr, 'php', 'JSONC trailing commas should not disable file associations')
    h.wait_for_indent(bufnr, expected, 'JSONC trailing commas should not disable editor settings')
    assert.same(expected, h.read_indent(bufnr))
  end)

  it('preserves comment-like text inside JSON strings', function()
    local root = h.mktemp_root(base, 'jsonc-string-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    write_vscode_settings(
      settings,
      [[
{
  "projectSettingsUrl": "http://example.com//still-a-string",
  "files.associations": {
    "*.stringjsonc": "php"
  },
  "[php]": {
    "editor.insertSpaces": false,
    "editor.tabSize": 3,
    "editor.detectIndentation": false
  }
}
]]
    )

    local file = h.join(root, 'sample.stringjsonc')
    h.write_file(file, "<?php\n  echo 'string';\n")

    local bufnr = h.edit(file)
    local expected = {
      expandtab = false,
      tabstop = 3,
      shiftwidth = 3,
      softtabstop = 3,
    }

    h.wait_for_filetype(bufnr, 'php', 'comment-like text inside strings must not break decoding')
    h.wait_for_indent(
      bufnr,
      expected,
      'comment-like text inside strings must not disable editor settings'
    )
    assert.same(expected, h.read_indent(bufnr))
  end)

  it('expands brace globs in project file associations', function()
    local root = h.mktemp_root(base, 'brace-expansion-root')
    local settings = h.join(root, '.vscode', 'settings.json')

    h.write_json(settings, {
      ['files.associations'] = {
        ['*.{fooassoc,barassoc}'] = 'php',
      },
    })

    local foo = h.join(root, 'sample.fooassoc')
    h.write_file(foo, "<?php\n  echo 'foo';\n")
    local foo_bufnr = h.edit(foo)
    h.wait_for_filetype(foo_bufnr, 'php', 'brace expansion should match the first alternative')
    assert.equals('php', vim.bo[foo_bufnr].filetype)

    local bar = h.join(root, 'sample.barassoc')
    h.write_file(bar, "<?php\n  echo 'bar';\n")
    local bar_bufnr = h.edit(bar)
    h.wait_for_filetype(bar_bufnr, 'php', 'brace expansion should match the second alternative')
    assert.equals('php', vim.bo[bar_bufnr].filetype)
  end)

  it('restores tooling bases on reload before reinstalling overrides', function()
    local project = require('configs.project')
    local tooling = require('configs.project.tooling')
    local root = h.mktemp_root(base, 'tooling-reload-root')
    local tooling_path = h.join(root, '.nvim', 'tooling.json')
    local file = h.join(root, 'sample.php')

    local base_formatter = function()
      return {
        command = 'stubfmt',
        args = { '--base' },
      }
    end

    local base_linter = function()
      return {
        cmd = 'stublint',
        args = { '--base' },
      }
    end

    local conform = {
      formatters = {
        stubfmt = base_formatter,
      },
    }
    local lint = {
      linters = {
        stublint = base_linter,
      },
    }

    local original_conform = package.loaded.conform
    local original_lint = package.loaded.lint
    package.loaded.conform = conform
    package.loaded.lint = lint

    local ok, err = xpcall(function()
      h.write_json(tooling_path, {
        filetypes = {
          php = {
            formatters = { 'stubfmt' },
            linters = { 'stublint' },
          },
        },
        formatters = {
          stubfmt = {
            args_append = { '--project-1' },
          },
        },
        linters = {
          stublint = {
            args_append = { '--project-1' },
          },
        },
      })

      h.write_file(file, "<?php\n  echo 'tooling';\n")
      local bufnr = h.edit(file)
      h.wait_for_filetype(bufnr, 'php', 'php filetype should be detected for tooling reload test')

      project.ensure_conform_overrides(bufnr)
      project.ensure_lint_overrides(bufnr)

      local conform_wrapper = conform.formatters.stubfmt
      local lint_wrapper = lint.linters.stublint

      assert.is_function(conform_wrapper)
      assert.is_function(lint_wrapper)
      assert.are_not.equal(base_formatter, conform_wrapper)
      assert.are_not.equal(base_linter, lint_wrapper)
      assert.same({ '--project-1' }, conform_wrapper(bufnr).append_args)
      assert.same({ '--base', '--project-1' }, lint_wrapper().args)

      h.write_json(tooling_path, {
        filetypes = {
          php = {
            formatters = { 'stubfmt' },
            linters = { 'stublint' },
          },
        },
        formatters = {
          stubfmt = {
            args_append = { '--project-2' },
          },
        },
        linters = {
          stublint = {
            args_append = { '--project-2' },
          },
        },
      })

      h.reload()

      assert.equal(base_formatter, conform.formatters.stubfmt)
      assert.equal(base_linter, lint.linters.stublint)

      project.ensure_conform_overrides(bufnr)
      project.ensure_lint_overrides(bufnr)

      local reinstalled_conform_wrapper = conform.formatters.stubfmt
      local reinstalled_lint_wrapper = lint.linters.stublint

      assert.is_function(reinstalled_conform_wrapper)
      assert.is_function(reinstalled_lint_wrapper)
      assert.are_not.equal(base_formatter, reinstalled_conform_wrapper)
      assert.are_not.equal(base_linter, reinstalled_lint_wrapper)
      assert.are_not.equal(conform_wrapper, reinstalled_conform_wrapper)
      assert.are_not.equal(lint_wrapper, reinstalled_lint_wrapper)
      assert.same({ '--project-2' }, reinstalled_conform_wrapper(bufnr).append_args)
      assert.same({ '--base', '--project-2' }, reinstalled_lint_wrapper().args)
    end, debug.traceback)

    tooling.invalidate()
    package.loaded.conform = original_conform
    package.loaded.lint = original_lint

    if not ok then
      error(err)
    end
  end)

  it('loads startup-root project settings through init without codesettings warning', function()
    local root = h.mktemp_root(base, 'startup-order-root')
    local settings = h.join(root, '.vscode', 'settings.json')
    local file = h.join(root, 'sample.startupcheck')
    local repo = vim.g.project_settings_test_repo_root
    local lazy_dir = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
    local codesettings_dir = vim.g.project_settings_test_codesettings_dir

    h.write_json(settings, {
      ['files.associations'] = {
        ['*.startupcheck'] = 'php',
      },
    })
    h.write_file(file, "<?php\n  echo 'startup';\n")

    local child_init = string.format(
      [[
local repo = %q
local lazy_dir = %q
local codesettings_dir = %q
local file = %q

vim.cmd('cd ' .. vim.fn.fnameescape(%q))
vim.opt.runtimepath:prepend(repo)
vim.opt.runtimepath:prepend(lazy_dir)
require('configs.bootstrap').setup({
  lazy = {
    specs = {
      {
        dir = codesettings_dir,
        name = 'codesettings.nvim',
        lazy = false,
        opts = {
          config_file_paths = { '.vscode/settings.json' },
          live_reload = false,
          jsonls_integration = false,
          lua_ls_integration = false,
          root_dir = function()
            return require('configs.project.json').find_root(0)
          end,
        },
        config = function(_, opts)
          require('codesettings').setup(opts)
        end,
      },
    },
  },
})
vim.cmd('edit ' .. vim.fn.fnameescape(file))

local ok = vim.wait(1000, function()
  return vim.bo.filetype == 'php'
end, 10, false)
if not ok then
  error('startup root did not apply file association: ' .. vim.bo.filetype)
end

local messages = vim.api.nvim_exec2('messages', { output = true }).output
if messages:find('codesettings%%.nvim is unavailable') then
  error('unexpected startup warning: ' .. messages)
end
]],
      repo,
      lazy_dir,
      codesettings_dir,
      file,
      root
    )

    local result = h.run_child_nvim({
      cwd = root,
      init = child_init,
      args = { '+qa!' },
    })

    assert.equals(0, result.code, result.stderr ~= '' and result.stderr or result.stdout)
  end)

  it('skips project bootstrap in vscode sessions without codesettings', function()
    local root = h.mktemp_root(base, 'vscode-skip-root')
    local settings = h.join(root, '.vscode', 'settings.json')
    local file = h.join(root, 'sample.vscodeskip')
    local repo = vim.g.project_settings_test_repo_root
    local lazy_dir = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

    h.write_json(settings, {
      ['files.associations'] = {
        ['*.vscodeskip'] = 'php',
      },
    })
    h.write_file(file, "<?php\n  echo 'skip';\n")

    local child_init = string.format(
      [[
local repo = %q
local lazy_dir = %q
local file = %q

vim.g.vscode = true
vim.cmd('cd ' .. vim.fn.fnameescape(%q))
vim.opt.runtimepath:prepend(repo)
vim.opt.runtimepath:prepend(lazy_dir)
require('configs.bootstrap').setup({
  lazy = {
    specs = {},
  },
})
vim.cmd('edit ' .. vim.fn.fnameescape(file))

local messages = vim.api.nvim_exec2('messages', { output = true }).output
if messages:find('codesettings%%.nvim is unavailable') then
  error('unexpected vscode warning: ' .. messages)
end
]],
      repo,
      lazy_dir,
      file,
      root
    )

    local result = h.run_child_nvim({
      cwd = root,
      init = child_init,
      args = { '+qa!' },
    })

    assert.equals(0, result.code, result.stderr ~= '' and result.stderr or result.stdout)
  end)
end)
