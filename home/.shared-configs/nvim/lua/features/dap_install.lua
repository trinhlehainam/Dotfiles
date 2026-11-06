local M = {}

---Keep Mason's adapter definitions, but resolve them only after installation.
---@param adapters string[]
function M.setup(adapters)
  local dap = require('dap')
  local installer = require('utils.mason_install')
  local packages = require('mason-nvim-dap.mappings.source').nvim_dap_to_package
  local filetypes = require('mason-nvim-dap.mappings.filetypes')
  local configurations = require('mason-nvim-dap.mappings.configurations')

  local function register(name, package, get_adapter)
    dap.adapters[name] = function(callback, config)
      installer.ensure({ package }, function(success)
        if not success then
          vim.notify(
            ('Debug adapter %s is unavailable. Retry :MasonInstall %s, then launch again.'):format(
              name,
              package
            ),
            vim.log.levels.WARN
          )
          return
        end
        local adapter = get_adapter()
        if type(adapter) == 'function' then
          adapter(callback, config)
        else
          callback(adapter)
        end
      end)
    end
  end

  for _, name in ipairs(adapters) do
    for _, ft in ipairs(filetypes[name]) do
      dap.configurations[ft] =
        vim.list_extend(dap.configurations[ft] or {}, configurations[name] or {})
    end
    register(name, packages[name], function()
      -- These definitions resolve executable paths when required, so defer require too.
      return require('mason-nvim-dap.mappings.adapters.' .. name)
    end)
  end

  -- Reuse the adapter defined in plugins/rustaceanvim.lua; Rust still owns launch settings.
  -- A callback also works inside neotest's nio task, whose coroutine we must not yield/resume.
  register('codelldb', 'codelldb', function()
    return vim.g.rustaceanvim.dap.adapter
  end)
end

return M
