local M = {}

-- Fake only the download boundary; callers still use real buffers and events.
function M.new()
  local state = { installed = {}, installing = {}, installs = {}, refreshes = {}, listeners = {} }
  local root = vim.fn.tempname()
  local function package_path(name)
    return vim.fs.joinpath(root, name)
  end
  state.location = {
    global = function()
      return {
        package = function(_, name)
          return package_path(name)
        end,
      }
    end,
  }
  function state.promote(name)
    vim.fn.mkdir(package_path(name), 'p')
    state.installed[name] = true
  end
  function state.seed(name)
    state.promote(name)
    vim.fn.writefile({ '{}' }, package_path(name) .. '/mason-receipt.json')
  end
  function state.cleanup()
    vim.fn.delete(root, 'rf')
  end
  local registry = {}
  function registry.is_installed(name)
    return state.installed[name] == true
  end
  function registry.refresh(callback)
    state.refreshes[#state.refreshes + 1] = callback
  end
  function registry:on(event, callback)
    state.listeners[event] = state.listeners[event] or {}
    table.insert(state.listeners[event], callback)
  end
  function registry.get_package(name)
    assert(name ~= 'unknown', 'Unknown package')
    return {
      name = name,
      is_installing = function()
        return state.installing[name] == true
      end,
      install = function()
        assert(not state.installing[name], 'Already installing')
        assert(name ~= 'throws', 'Installer error')
        state.installing[name] = true
        state.installs[#state.installs + 1] = name
      end,
    }
  end
  function state.finish(name, success)
    state.installing[name] = nil
    state.installed[name] = success
    if success then
      state.seed(name)
    else
      vim.fn.delete(package_path(name), 'rf')
    end
    local event = 'package:install:' .. (success and 'success' or 'failed')
    for _, callback in ipairs(state.listeners[event] or {}) do
      callback({ name = name })
    end
  end
  function state.refresh(success)
    local callbacks = state.refreshes
    state.refreshes = {}
    for _, callback in ipairs(callbacks) do
      callback(success ~= false)
    end
  end
  return registry, state
end

return M
