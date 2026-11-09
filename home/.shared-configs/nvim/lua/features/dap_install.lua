local M = {}
local pending_launches = 0

---Ignore repeated F5 presses while the first launch is preparing its adapter.
---Keep adapter callbacks intact: neotest and other API callers may be waiting on them.
function M.continue()
  if pending_launches > 0 then
    vim.notify('Debugger setup is pending; the requested launch will resume when ready.')
    return
  end
  require('dap').continue()
end

---Keep Mason's adapter definitions, but resolve them only after installation.
---@param adapters string[]
function M.setup(adapters)
  local dap = require('dap')
  local installer = require('utils.mason_install')
  local packages = require('mason-nvim-dap.mappings.source').nvim_dap_to_package
  local filetypes = require('mason-nvim-dap.mappings.filetypes')
  local configurations = require('mason-nvim-dap.mappings.configurations')

  local function register(name, package, get_adapter)
    local requested = false
    dap.adapters[name] = function(callback, config)
      if not requested and not installer.is_ready(package) then
        vim.notify(
          ('Installing %s for debugging; the launch will resume when ready.'):format(package)
        )
      end
      requested = true
      installer.ensure({ package }, function(success)
        pending_launches = pending_launches - 1
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
      -- ensure() schedules its callback; count only requests that return successfully.
      pending_launches = pending_launches + 1
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
