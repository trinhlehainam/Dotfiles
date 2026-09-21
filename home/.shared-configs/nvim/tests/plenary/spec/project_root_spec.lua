local h = require('project_settings_harness')
local project_json = require('configs.project.json')

h.setup()

describe('project root discovery', function()
  it('uses the nearest marker regardless of marker order', function()
    local root = h.mktemp_root(h.new_base(), 'parent')
    h.write_file(h.join(root, '.git'), 'gitdir: /tmp/project-test-git\n')
    local nested = h.join(root, 'nested')
    h.write_json(h.join(nested, '.vscode', 'settings.json'), {})

    assert.equals(nested, project_json.find_root_for_path(nested))
    assert.equals(nested, project_json.find_root_for_path(h.join(nested, 'new.php')))
    assert.equals(root, project_json.find_root_for_path(h.join(root, 'new.php')))
  end)

  it('handles existing files and new files under missing directories', function()
    local root = h.mktemp_root(h.new_base(), 'files')
    h.write_json(h.join(root, '.nvim', 'tooling.json'), {})
    local existing = h.join(root, 'existing.php')
    h.write_file(existing, '')

    assert.equals(root, project_json.find_root_for_path(existing))
    assert.equals(root, project_json.find_root_for_path(h.join(root, 'missing', 'new.php')))
    assert.is_nil(project_json.find_root_for_path(''))
  end)
end)
