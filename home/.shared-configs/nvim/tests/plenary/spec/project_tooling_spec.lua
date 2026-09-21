local h = require('project_settings_harness')

h.setup()

local conform = require('conform')
local tooling = require('configs.project.tooling')

describe('project formatter inheritance', function()
  local root

  before_each(function()
    h.reset_to_scratch()
    root = h.mktemp_root(h.new_base(), 'formatter-inheritance')
  end)

  after_each(function()
    tooling.invalidate()
    conform.formatters.project_custom = nil
  end)

  local cases = {
    {
      name = 'preserves formatter inherit=false',
      inherit = false,
      args = { '--base' },
      expected_args = { '--base', '--project' },
    },
    {
      name = 'preserves formatter inherit=stylua',
      inherit = 'stylua',
      args = { '--base' },
      expected_args = { '--base', '--project' },
    },
    {
      name = 'appends arguments to a custom formatter with implicit inheritance',
      args = { '--base' },
      expected_args = { '--base', '--project' },
    },
    {
      name = 'appends arguments to an argless custom formatter with implicit inheritance',
      expected_args = { '--project' },
    },
  }

  for _, case in ipairs(cases) do
    it(case.name, function()
      conform.formatters.project_custom = {
        command = 'customfmt',
        args = case.args,
        inherit = case.inherit,
      }
      h.write_json(h.join(root, '.nvim', 'tooling.json'), {
        filetypes = { lua = { formatters = { 'project_custom' } } },
        formatters = { project_custom = { args_append = { '--project' } } },
      })
      local file = h.join(root, 'sample.lua')
      h.write_file(file, '')
      local bufnr = h.edit(file)
      assert.same({ 'project_custom' }, tooling.get_formatters(bufnr))

      local config, err = conform.get_formatter_config('project_custom', bufnr)

      assert.is_nil(err)
      assert.is_table(config)
      assert.equals('customfmt', config.command)
      if case.inherit ~= nil then
        assert.equals(case.inherit, conform.formatters.project_custom(bufnr).inherit)
      end
      local args = config.args
      if type(args) == 'function' then
        args = args(config, { bufnr = bufnr })
      end
      assert.same(case.expected_args, args)
    end)
  end
end)
