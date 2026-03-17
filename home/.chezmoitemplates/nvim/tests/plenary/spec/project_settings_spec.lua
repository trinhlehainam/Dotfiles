local h = require('project_settings_harness')

h.setup()

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
    h.wait_for_indent(bufnr, expected, 'project settings should win after BufReadPost indentation changes')

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
    h.wait_for_indent(bufnr, expected, 'later-opened root should apply project indentation on first open')

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
    h.write_file(file, "<div>{{ value }}</div>\n")

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
    h.write_file(file, "<?php\n\treturn 1;\n")

    local bufnr = h.edit(file)
    local overridden = {
      expandtab = true,
      tabstop = 8,
      shiftwidth = 8,
      softtabstop = 8,
    }

    h.wait_for_indent(bufnr, overridden, 'project-local indent override should apply before reload reset')
    assert.same(overridden, h.read_indent(bufnr))

    h.write_json(settings, {})
    h.reload()

    h.wait_for_indent(bufnr, defaults, 'reload should restore default php indentation after removing project override')
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
    h.wait_for_filetype(bufnr, 'php', 'php filetype should be detected before manual indent override')

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
end)
