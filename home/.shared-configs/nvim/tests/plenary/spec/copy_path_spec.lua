describe('utils.copy_path', function()
  local copy_path
  local original_has
  local original_notify
  local original_select
  local original_setreg
  local notifications
  local register_writes

  before_each(function()
    package.loaded['utils.copy_path'] = nil

    original_has = vim.fn.has
    original_notify = vim.notify
    original_select = vim.ui.select
    original_setreg = vim.fn.setreg

    notifications = {}
    register_writes = {}

    vim.fn.has = function(feature)
      if feature == 'clipboard' then
        return 1
      end
      return original_has(feature)
    end
    vim.notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end
    vim.fn.setreg = function(register, value)
      register_writes[#register_writes + 1] = { register = register, value = value }
      return 0
    end

    copy_path = require('utils.copy_path')
  end)

  after_each(function()
    vim.fn.has = original_has
    vim.notify = original_notify
    vim.ui.select = original_select
    vim.fn.setreg = original_setreg
    package.loaded['utils.copy_path'] = nil
  end)

  it('offers six path variants and copies the selected value', function()
    local filepath = vim.fs.joinpath(vim.fn.getcwd(), 'dir', 'file.test.lua')
    local relative_filepath = vim.fs.joinpath('dir', 'file.test.lua')
    local choices
    local select_opts

    vim.ui.select = function(items, opts, on_choice)
      choices = items
      select_opts = opts
      on_choice(items[2])
    end

    copy_path.select(filepath)

    assert.same({
      { label = 'Absolute path', value = filepath },
      { label = 'Path relative to CWD', value = relative_filepath },
      { label = 'Path relative to HOME', value = vim.fn.fnamemodify(filepath, ':~') },
      { label = 'Filename', value = 'file.test.lua' },
      { label = 'Filename without extension', value = 'file.test' },
      { label = 'Extension of the filename', value = 'lua' },
    }, choices)
    assert.equals('Choose to copy to clipboard:', select_opts.prompt)
    assert.is_truthy(select_opts.format_item(choices[2]):find(relative_filepath, 1, true))
    assert.same({
      { register = '+', value = relative_filepath },
    }, register_writes)
    assert.same({
      {
        message = 'Copied to clipboard: ' .. relative_filepath,
        level = nil,
      },
    }, notifications)
  end)

  it('leaves the clipboard unchanged when selection is cancelled', function()
    vim.ui.select = function(_, _, on_choice)
      on_choice(nil)
    end

    copy_path.select('/tmp/file.lua')

    assert.same({}, register_writes)
    assert.same({
      { message = 'Copy cancelled.', level = vim.log.levels.INFO },
    }, notifications)
  end)

  it('warns when no file path is available', function()
    local select_called = false
    vim.ui.select = function()
      select_called = true
    end

    copy_path.select(nil)

    assert.is_false(select_called)
    assert.same({}, register_writes)
    assert.same({
      { message = 'No file path available.', level = vim.log.levels.WARN },
    }, notifications)
  end)

  it('reports an unavailable system clipboard before opening the picker', function()
    local select_called = false
    vim.fn.has = function(feature)
      return feature == 'clipboard' and 0 or original_has(feature)
    end
    vim.ui.select = function()
      select_called = true
    end

    copy_path.select('/tmp/file.lua')

    assert.is_false(select_called)
    assert.same({}, register_writes)
    assert.same({
      { message = 'System clipboard is not available.', level = vim.log.levels.ERROR },
    }, notifications)
  end)
end)

describe('copy path integrations', function()
  local captured_mapping
  local copied_path
  local created_bufnr
  local original_autocmd
  local original_bufnr
  local original_copy_path
  local original_keymap_set
  local original_mapleader
  local original_maplocalleader
  local original_notify

  before_each(function()
    original_autocmd = vim.api.nvim_create_autocmd
    original_bufnr = vim.api.nvim_get_current_buf()
    original_copy_path = package.loaded['utils.copy_path']
    original_keymap_set = vim.keymap.set
    original_mapleader = vim.g.mapleader
    original_maplocalleader = vim.g.maplocalleader
    original_notify = vim.notify

    captured_mapping = nil
    copied_path = nil
    created_bufnr = nil

    package.loaded['utils.copy_path'] = {
      select = function(filepath)
        copied_path = filepath
      end,
    }

    vim.api.nvim_create_autocmd = function()
      return 1
    end
    vim.notify = function() end
    vim.keymap.set = function(mode, lhs, rhs, opts)
      if lhs == '<leader>yp' then
        captured_mapping = { mode = mode, rhs = rhs, opts = opts }
      end
    end
  end)

  after_each(function()
    vim.api.nvim_create_autocmd = original_autocmd
    vim.keymap.set = original_keymap_set
    vim.g.mapleader = original_mapleader
    vim.g.maplocalleader = original_maplocalleader
    vim.notify = original_notify

    if vim.api.nvim_buf_is_valid(original_bufnr) then
      vim.api.nvim_set_current_buf(original_bufnr)
    end
    if created_bufnr and vim.api.nvim_buf_is_valid(created_bufnr) then
      pcall(vim.api.nvim_buf_delete, created_bufnr, { force = true })
    end

    package.loaded['utils.copy_path'] = original_copy_path
  end)

  it('passes the selected Neo-tree node path to the shared helper', function()
    local filepath = '/tmp/project/file.lua'
    local spec = dofile(vim.g.project_settings_test_repo_root .. '/lua/plugins/neo-tree.lua')

    spec.opts.window.mappings.Y({
      tree = {
        get_node = function()
          return { path = filepath }
        end,
      },
    })

    assert.equals(filepath, copied_path)
  end)

  it('maps leader yp to copy the active regular buffer path', function()
    local filepath = vim.fs.joinpath(vim.fn.getcwd(), 'active-buffer.lua')
    created_bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(created_bufnr, filepath)
    vim.api.nvim_set_current_buf(created_bufnr)

    dofile(vim.g.project_settings_test_repo_root .. '/lua/configs/keymaps.lua')

    assert.is_table(captured_mapping)
    assert.equals('n', captured_mapping.mode)
    assert.equals('[Y]ank file [P]ath', captured_mapping.opts.desc)

    captured_mapping.rhs()

    assert.equals(filepath, copied_path)
  end)

  it('does not copy a special buffer name as a file path', function()
    created_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(created_bufnr, 'term://shell')
    vim.api.nvim_set_current_buf(created_bufnr)

    dofile(vim.g.project_settings_test_repo_root .. '/lua/configs/keymaps.lua')
    captured_mapping.rhs()

    assert.is_nil(copied_path)
  end)
end)
