local php = require('configs.lsp.php')

local config = php.lspconfigs[1].config
local command_name = 'IntelephenseIndexWorkspace'

local function get_upvalue(fn, expected_name)
  for index = 1, 20 do
    local name, value = debug.getupvalue(fn, index)
    if not name then
      break
    end

    if name == expected_name then
      return value
    end
  end

  error('missing upvalue: ' .. expected_name)
end

local function set_upvalue(fn, expected_name, new_value)
  for index = 1, 20 do
    local name = debug.getupvalue(fn, index)
    if not name then
      break
    end

    if name == expected_name then
      debug.setupvalue(fn, index, new_value)
      return
    end
  end

  error('missing upvalue: ' .. expected_name)
end

local register_commands_once = get_upvalue(config.on_attach, 'register_commands_once')
local track_active_client_buffer = get_upvalue(config.on_attach, 'track_active_client_buffer')
local active_clients = get_upvalue(track_active_client_buffer, 'active_clients')
local on_exit = get_upvalue(config.on_exit, 'fn')
local unregister_commands = get_upvalue(on_exit, 'unregister_commands')

local function make_client(id, root_dir)
  local client = {
    id = id,
    name = 'intelephense',
    config = { root_dir = root_dir },
    stopped = false,
  }

  function client:supports_method()
    return false
  end

  function client:stop(force)
    assert.is_false(force)
    self.stopped = true
  end

  function client:is_stopped()
    return self.stopped
  end

  return client
end

describe('configs.lsp.php index command', function()
  local bufnr
  local original_get_clients
  local original_lsp_config
  local original_schedule
  local original_start

  before_each(function()
    pcall(vim.api.nvim_del_user_command, command_name)
    for client_id in pairs(active_clients) do
      active_clients[client_id] = nil
    end
    set_upvalue(register_commands_once, 'commands_registered', false)

    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)

    original_get_clients = vim.lsp.get_clients
    original_lsp_config = vim.lsp.config
    original_schedule = vim.schedule
    original_start = vim.lsp.start
  end)

  after_each(function()
    vim.lsp.get_clients = original_get_clients
    vim.lsp.config = original_lsp_config
    vim.schedule = original_schedule
    vim.lsp.start = original_start

    pcall(vim.api.nvim_del_user_command, command_name)
    for client_id in pairs(active_clients) do
      active_clients[client_id] = nil
    end
    set_upvalue(register_commands_once, 'commands_registered', false)

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end)

  it('restarts the Intelephense client attached to the current buffer', function()
    local attached_client = make_client(9902, '/workspace/current')
    local other_client = make_client(9903, '/workspace/other')
    local observed_filter
    local started_config

    vim.lsp.get_clients = function(filter)
      observed_filter = vim.deepcopy(filter)
      return filter.bufnr == 0 and { attached_client } or { other_client }
    end
    vim.lsp.config = {}
    vim.lsp.start = function(start_config)
      started_config = start_config
    end

    config.on_attach(attached_client, bufnr)
    vim.cmd(command_name)

    assert.same({ bufnr = 0, name = 'intelephense' }, observed_filter)
    assert.is_true(attached_client.stopped)
    assert.is_false(other_client.stopped)
    assert.equals('/workspace/current', started_config.root_dir)
  end)

  it('explicitly disables inherited cache clearing without a bang', function()
    local client = make_client(9904, '/workspace/current')
    local started_config

    vim.lsp.get_clients = function()
      return { client }
    end
    vim.lsp.config = {
      intelephense = {
        init_options = { clearCache = true },
      },
    }
    vim.lsp.start = function(start_config)
      started_config = start_config
    end

    config.on_attach(client, bufnr)
    vim.cmd(command_name)

    assert.is_false(started_config.init_options.clearCache)
  end)

  it('keeps the command when a replacement client attaches before deferred cleanup', function()
    local client = make_client(9905, '/workspace/current')
    local replacement = make_client(9906, '/workspace/current')
    local scheduled = {}

    config.on_attach(client, bufnr)
    active_clients[client.id] = nil

    vim.schedule = function(callback)
      scheduled[#scheduled + 1] = callback
    end
    unregister_commands()
    config.on_attach(replacement, bufnr)

    assert.equals(1, #scheduled)
    scheduled[1]()

    assert.equals(2, vim.fn.exists(':' .. command_name))
  end)
end)
