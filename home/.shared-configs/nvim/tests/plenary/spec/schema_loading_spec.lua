describe('schema catalogs', function()
  local modules = { 'configs.lsp.json', 'configs.lsp.yaml', 'schemastore' }
  local saved

  before_each(function()
    saved = {}
    for _, name in ipairs(modules) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end
  end)

  after_each(function()
    for _, name in ipairs(modules) do
      package.loaded[name] = saved[name]
    end
  end)

  it('builds catalogs only when a JSON or YAML server initializes', function()
    local calls = {}
    package.loaded.schemastore = {
      json = {
        schemas = function(opts)
          calls.json = opts.extra
          return { { name = 'json-schema' } }
        end,
      },
      yaml = {
        schemas = function()
          calls.yaml = true
          return { ['yaml-schema'] = '*.yaml' }
        end,
      },
    }
    local json = require('configs.lsp.json').servers.jsonls
    local yaml = require('configs.lsp.yaml').servers.yamlls
    assert.same({}, calls)

    local json_config = vim.deepcopy(json)
    local yaml_config = vim.deepcopy(yaml)
    json.before_init({}, json_config)
    yaml.before_init({}, yaml_config)
    assert.equals('komorebi.json', calls.json[1].name)
    assert.same({ { name = 'json-schema' } }, json_config.settings.json.schemas)
    assert.same({ ['yaml-schema'] = '*.yaml' }, yaml_config.settings.yaml.schemas)
    assert.is_nil(json.settings.json.schemas)
    assert.is_nil(yaml.settings.yaml.schemas)
  end)
end)
