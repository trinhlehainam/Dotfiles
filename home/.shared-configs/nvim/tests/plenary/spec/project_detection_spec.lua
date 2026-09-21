local h = require('project_settings_harness')

h.setup()

describe('project filetype detection', function()
  local base

  before_each(function()
    h.reset_to_scratch()
    base = h.new_base()
  end)

  it('preserves builtin extension detection outside an associated project', function()
    local root = h.mktemp_root(base, 'lua-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['files.associations'] = { ['*.lua'] = 'php' },
    })
    local associated = h.join(root, 'associated.lua')
    h.write_file(associated, '')
    h.wait_for_filetype(h.edit(associated), 'php', 'project association should override lua')

    local unrelated = h.join(base, 'outside', 'unrelated.lua')
    h.write_file(unrelated, '')
    h.wait_for_filetype(
      h.edit(unrelated),
      'lua',
      'outside project should keep builtin lua detection'
    )
  end)

  it('preserves builtin filename detection outside an associated project', function()
    local root = h.mktemp_root(base, 'cmake-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['files.associations'] = { ['CMakeLists.txt'] = 'php' },
    })
    local associated = h.join(root, 'CMakeLists.txt')
    h.write_file(associated, '')
    h.wait_for_filetype(
      h.edit(associated),
      'php',
      'project association should override CMakeLists.txt'
    )

    local unrelated = h.join(base, 'outside', 'CMakeLists.txt')
    h.write_file(unrelated, '')
    h.wait_for_filetype(
      h.edit(unrelated),
      'cmake',
      'outside project should keep builtin CMakeLists.txt detection'
    )
  end)

  it('restores builtin extension detection after removing an association', function()
    local root = h.mktemp_root(base, 'removed-lua-project')
    local settings = h.join(root, '.vscode', 'settings.json')
    h.write_json(settings, { ['files.associations'] = { ['*.lua'] = 'php' } })
    local file = h.join(root, 'associated.lua')
    h.write_file(file, '')
    local bufnr = h.edit(file)
    h.wait_for_filetype(bufnr, 'php', 'project association should override lua')

    h.write_json(settings, {})
    h.reload()

    h.wait_for_filetype(bufnr, 'lua', 'removing association should restore builtin lua detection')
  end)

  it('restores builtin filename detection after removing an association', function()
    local root = h.mktemp_root(base, 'removed-cmake-project')
    local settings = h.join(root, '.vscode', 'settings.json')
    h.write_json(settings, { ['files.associations'] = { ['CMakeLists.txt'] = 'php' } })
    local file = h.join(root, 'CMakeLists.txt')
    h.write_file(file, '')
    local bufnr = h.edit(file)
    h.wait_for_filetype(bufnr, 'php', 'project association should override CMakeLists.txt')

    h.write_json(settings, {})
    h.reload()

    h.wait_for_filetype(
      bufnr,
      'cmake',
      'removing association should restore builtin CMakeLists.txt detection'
    )
  end)

  it('applies associations to the first new file opened in a project', function()
    local root = h.mktemp_root(base, 'new-file-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['files.associations'] = { ['*.newprojectassoc'] = 'php' },
    })

    local bufnr = h.edit(h.join(root, 'never-created.newprojectassoc'))

    h.wait_for_filetype(bufnr, 'php', 'first BufNewFile should use project association')
  end)

  it('matches double-star globs with zero or several directories', function()
    local root = h.mktemp_root(base, 'double-star-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['files.associations'] = { ['**/*.doublestarassoc'] = 'php' },
    })

    for _, relative in ipairs({ 'sample.doublestarassoc', 'one/two/sample.doublestarassoc' }) do
      local file = h.join(root, relative)
      h.write_file(file, '')
      h.wait_for_filetype(
        h.edit(file),
        'php',
        '** should match zero or more directories: ' .. relative
      )
    end
  end)

  it('keeps parent path associations out of a nested independent project', function()
    local root = h.mktemp_root(base, 'parent-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['files.associations'] = { ['**/*.nestedprojectassoc'] = 'php' },
    })
    local parent_file = h.join(root, 'src', 'sample.nestedprojectassoc')
    h.write_file(parent_file, '')
    h.wait_for_filetype(
      h.edit(parent_file),
      'php',
      'parent association should apply in parent project'
    )

    local nested = h.join(root, 'nested')
    h.write_json(h.join(nested, '.vscode', 'settings.json'), {})
    local nested_file = h.join(nested, 'sample.nestedprojectassoc')
    h.write_file(nested_file, '')

    h.wait_for_filetype(
      h.edit(nested_file),
      '',
      'nested project should not inherit parent association'
    )
  end)

  it('preserves manual filetypes for known extensions on reload', function()
    local root = h.mktemp_root(base, 'manual-python-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {})
    local file = h.join(root, 'manual.py')
    h.write_file(file, '')
    local bufnr = h.edit(file)
    h.wait_for_filetype(bufnr, 'python', 'builtin python detection should run first')
    vim.bo[bufnr].filetype = 'text'

    h.reload()

    h.wait_for_filetype(bufnr, 'text', 'reload should preserve manual filetype for known extension')
  end)

  it('matches character classes in association globs', function()
    local root = h.mktemp_root(base, 'character-class-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['files.associations'] = { ['file[12].classprojectassoc'] = 'php' },
    })

    for _, number in ipairs({ 1, 2, 3 }) do
      local file = h.join(root, 'file' .. number .. '.classprojectassoc')
      h.write_file(file, '')
      local expected = number < 3 and 'php' or ''
      h.wait_for_filetype(
        h.edit(file),
        expected,
        'character class should match only listed characters'
      )
    end
  end)

  it('gives exact filenames precedence over extension associations', function()
    local root = h.mktemp_root(base, 'precedence-project')
    h.write_json(h.join(root, '.vscode', 'settings.json'), {
      ['files.associations'] = {
        ['*.precedenceassoc'] = 'php',
        ['special.precedenceassoc'] = 'html',
      },
    })
    local file = h.join(root, 'special.precedenceassoc')
    h.write_file(file, '')

    h.wait_for_filetype(
      h.edit(file),
      'html',
      'exact filename should win over extension association'
    )
  end)
end)
