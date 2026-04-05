local function make_emitter()
  local listeners = {}

  return {
    listeners = listeners,
    on = function(_, event, callback)
      local callbacks = listeners[event] or {}
      callbacks[#callbacks + 1] = callback
      listeners[event] = callbacks
    end,
    emit = function(_, event, ...)
      for _, callback in ipairs(listeners[event] or {}) do
        callback(...)
      end
    end,
  }
end

describe('plugins.git Diffview CodeLens sync', function()
  local stubbed_module_names = {
    'utils.lsp_codelens',
    'configs.project.options',
    'neogit',
    'diffview',
    'diffview.lib',
    'plugins.git',
  }
  local original_modules
  local original_keymap_set
  local created_bufs
  local hooks
  local current_view
  local codelens_calls

  local function make_buf(name)
    local bufnr = vim.api.nvim_create_buf(false, true)
    if name then
      vim.api.nvim_buf_set_name(bufnr, name)
    end
    created_bufs[#created_bufs + 1] = bufnr
    return bufnr
  end

  local function make_view(main_buf)
    local emitter = make_emitter()
    local view = {
      emitter = emitter,
      cur_layout = {
        get_main_win = function()
          return {
            id = vim.api.nvim_get_current_win(),
            file = { bufnr = main_buf },
          }
        end,
      },
    }

    return view, emitter
  end

  before_each(function()
    original_modules = {}
    created_bufs = {}
    hooks = nil
    current_view = nil
    codelens_calls = {}

    for _, module_name in ipairs(stubbed_module_names) do
      original_modules[module_name] = package.loaded[module_name]
      package.loaded[module_name] = nil
    end

    package.loaded['utils.lsp_codelens'] = {
      set_context = function(bufnr, key, placement)
        codelens_calls[#codelens_calls + 1] = {
          fn = 'set_context',
          bufnr = bufnr,
          key = key,
          placement = placement,
        }
      end,
      clear_context = function(bufnr, key)
        codelens_calls[#codelens_calls + 1] = {
          fn = 'clear_context',
          bufnr = bufnr,
          key = key,
        }
      end,
    }
    package.loaded['configs.project.options'] = {
      apply_filetype_settings_for_root = function() end,
    }
    package.loaded['neogit'] = {
      setup = function() end,
      open = function() end,
    }
    package.loaded['diffview'] = {
      setup = function(config)
        hooks = config.hooks
      end,
      emit = function() end,
    }
    package.loaded['diffview.lib'] = {
      get_current_view = function()
        return current_view
      end,
    }

    original_keymap_set = vim.keymap.set
    vim.keymap.set = function() end
  end)

  after_each(function()
    vim.keymap.set = original_keymap_set

    for _, bufnr in ipairs(created_bufs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
    end

    for _, module_name in ipairs(stubbed_module_names) do
      package.loaded[module_name] = original_modules[module_name]
    end
  end)

  it('seeds Diffview CodeLens ownership on view_opened', function()
    local spec = require('plugins.git')[1]
    spec.config()

    assert.is_table(hooks)

    local buf1 = make_buf('diffview://repo/1/file1')
    local view = make_view(buf1)
    current_view = view

    hooks.view_opened(view)

    assert.same({
      {
        fn = 'set_context',
        bufnr = buf1,
        key = 'diffview',
        placement = 'eol',
      },
    }, codelens_calls)
  end)

  it('keeps view_enter as a defensive resync when returning to a Diffview tab', function()
    local spec = require('plugins.git')[1]
    spec.config()

    assert.is_table(hooks)

    local buf1 = make_buf('diffview://repo/1/file1')
    local buf2 = make_buf('diffview://repo/1/file2')
    local view = make_view(buf1)
    current_view = view

    hooks.view_opened(view)
    hooks.view_leave()

    codelens_calls = {}
    view.cur_layout.get_main_win = function()
      return {
        id = vim.api.nvim_get_current_win(),
        file = { bufnr = buf2 },
      }
    end

    hooks.view_enter(view)

    assert.same({
      {
        fn = 'set_context',
        bufnr = buf2,
        key = 'diffview',
        placement = 'eol',
      },
    }, codelens_calls)
  end)
end)
