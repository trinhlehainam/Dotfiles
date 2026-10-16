local php = require('configs.lsp.php')

local Methods = vim.lsp.protocol.Methods
local config = php.servers.intelephense

-- This spec intentionally reaches into features/intelephense.lua through private upvalues so it
-- can exercise the real diagnostic helpers without widening the runtime API.
-- It is coupled to php.lua's closure graph. Most lookups are by name, but a
-- few stable slots are used where PlenaryBustedFile has not been reliable
-- about exposing the nested helper name during spec load.
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

local function get_upvalue_at(fn, index)
  local _, value = debug.getupvalue(fn, index)
  if value == nil then
    error('missing upvalue index: ' .. tostring(index))
  end

  return value
end

local schedule_unused_reference_refresh =
  get_upvalue(config.on_attach, 'schedule_unused_reference_refresh')
local apply_unused_reference_diagnostics =
  get_upvalue(schedule_unused_reference_refresh, 'apply_unused_reference_diagnostics')
local set_unused_reference_diagnostics = get_upvalue_at(apply_unused_reference_diagnostics, 3)
local unused_refs_states = get_upvalue(config.on_attach, 'unused_refs_states')

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = 'php'
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function get_unused_reference_diagnostics(bufnr)
  return vim.tbl_filter(function(diagnostic)
    return diagnostic.source == 'intelephense' and diagnostic.code == 'P1003'
  end, vim.diagnostic.get(bufnr))
end

local function assert_unused_reference_hint(bufnr)
  local diagnostics = get_unused_reference_diagnostics(bufnr)
  assert.equals(1, #diagnostics)
  assert.same({
    lnum = 1,
    col = 9,
    message = "Symbol 'unused' is declared but not used.",
    severity = vim.diagnostic.severity.HINT,
    source = 'intelephense',
    code = 'P1003',
  }, {
    lnum = diagnostics[1].lnum,
    col = diagnostics[1].col,
    message = diagnostics[1].message,
    severity = diagnostics[1].severity,
    source = diagnostics[1].source,
    code = diagnostics[1].code,
  })
end

local function unresolved_unused_lens()
  return {
    range = {
      start = { line = 1, character = 9 },
      ['end'] = { line = 1, character = 15 },
    },
    data = { symbol = 'unused' },
  }
end

describe('configs.lsp.php unused reference diagnostics', function()
  local bufnr
  local client
  local requests
  local resolve_unused_reference_lenses

  before_each(function()
    resolve_unused_reference_lenses = get_upvalue_at(apply_unused_reference_diagnostics, 1)
    requests = { resolve = 0 }

    client = {
      id = 9901,
      name = 'intelephense',
      offset_encoding = 'utf-16',
    }

    function client:supports_method(method)
      return method == Methods.codeLens_resolve or method == Methods.textDocument_codeLens
    end

    function client:request(method, params, callback, target_bufnr)
      assert.equals(Methods.codeLens_resolve, method)

      requests.resolve = requests.resolve + 1
      local line = vim.api.nvim_buf_get_lines(target_bufnr, 1, 2, false)[1] or ''
      assert.matches('^function unused', line)

      local resolved_lens = vim.deepcopy(params)
      resolved_lens.command = { title = '0 References' }
      callback(nil, resolved_lens)
    end
  end)

  after_each(function()
    if bufnr then
      unused_refs_states[bufnr] = nil
    end

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end)

  local function apply_fallback_lenses()
    local lens = unresolved_unused_lens()

    if client:supports_method(Methods.codeLens_resolve, bufnr) then
      client:request(Methods.codeLens_resolve, lens, function(err, resolved_lens)
        assert.is_nil(err)
        set_unused_reference_diagnostics(bufnr, client, { resolved_lens })
      end, bufnr)
      return
    end

    set_unused_reference_diagnostics(bufnr, client, { lens })
  end

  it(
    'restores the unused-reference hint after delete and restore when fallback lenses require resolve',
    function()
      bufnr = make_buf({
        '<?php',
        'function unused() {}',
        "echo 'ready';",
      })

      apply_fallback_lenses()

      assert.equals(1, requests.resolve)
      assert_unused_reference_hint(bufnr)

      requests.resolve = 0

      vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})
      vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { 'function unused() {}' })

      apply_fallback_lenses()

      assert.equals(1, requests.resolve)
      assert_unused_reference_hint(bufnr)
    end
  )

  it('resolves unresolved lenses before applying shared cached diagnostics', function()
    bufnr = make_buf({
      '<?php',
      'function unused() {}',
      "echo 'ready';",
    })

    local state = { refresh_seq = 1 }
    unused_refs_states[bufnr] = state

    resolve_unused_reference_lenses(bufnr, client, state, state.refresh_seq, {
      unresolved_unused_lens(),
    }, function(resolved_lenses)
      set_unused_reference_diagnostics(bufnr, client, resolved_lenses)
    end)

    assert.equals(1, requests.resolve)
    assert_unused_reference_hint(bufnr)
  end)
end)

describe('Intelephense refresh scheduling', function()
  local bufnr, client, original_get, original_clients, original_client
  local cache_reads, direct_requests, cached_lenses

  local function cache_unused_lens()
    local lens = unresolved_unused_lens()
    lens.command = { title = '0 References' }
    cached_lenses = { { lens = lens, client_id = client.id } }
  end

  before_each(function()
    bufnr = make_buf({ '<?php', 'function unused() {}' })
    cache_reads, direct_requests = 0, 0
    client = {
      id = 9902,
      name = 'intelephense',
      offset_encoding = 'utf-16',
      supports_method = function()
        return true
      end,
      request = function()
        direct_requests = direct_requests + 1
        return true
      end,
    }
    original_get = vim.lsp.codelens.get
    original_clients = vim.lsp.get_clients
    original_client = vim.lsp.get_client_by_id
    vim.lsp.get_clients = function()
      return { client }
    end
    vim.lsp.get_client_by_id = function()
      return client
    end
    cache_unused_lens()
    vim.lsp.codelens.get = function()
      cache_reads = cache_reads + 1
      return cached_lenses
    end
    config.on_attach(client, bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.lsp.codelens.get = original_get
    vim.lsp.get_clients = original_clients
    vim.lsp.get_client_by_id = original_client
  end)

  local function request_event(kind, id, method)
    vim.api.nvim_exec_autocmds('LspRequest', {
      buffer = bufnr,
      data = {
        client_id = client.id,
        request_id = id,
        request = { type = kind, method = method or Methods.textDocument_codeLens, bufnr = bufnr },
      },
    })
  end

  it('does no lens scans while typing and consumes one completed shared request', function()
    for index = 1, 50 do
      vim.api.nvim_buf_set_lines(bufnr, 2, -1, false, { '// edit ' .. index })
    end
    assert.equals(0, cache_reads)
    assert.equals(0, direct_requests)

    request_event('pending', 1)
    request_event('complete', 1)
    -- The response handler runs after LspRequest and replaces lens objects,
    -- even when their contents are unchanged.
    cache_unused_lens()
    assert.is_true(vim.wait(300, function()
      return cache_reads == 2
    end, 10))
    assert_unused_reference_hint(bufnr)
    assert.equals(0, direct_requests)

    local seq = unused_refs_states[bufnr].refresh_seq
    request_event('pending', 2, Methods.codeLens_resolve)
    request_event('complete', 2, Methods.codeLens_resolve)
    assert.equals(seq, unused_refs_states[bufnr].refresh_seq)
  end)

  it('falls back once without treating its own reply as a shared-cache refresh', function()
    local reply
    client.request = function(_, method, _, callback)
      assert.equals(Methods.textDocument_codeLens, method)
      direct_requests = direct_requests + 1
      reply = callback
      request_event('pending', 99)
      return true, 99
    end
    assert.is_true(vim.wait(1200, function()
      return reply ~= nil
    end, 10))
    local seq = unused_refs_states[bufnr].refresh_seq
    request_event('complete', 99)
    assert.equals(seq, unused_refs_states[bufnr].refresh_seq)
    local lens = unresolved_unused_lens()
    lens.command = { title = '0 References' }
    reply(nil, { lens })
    assert_unused_reference_hint(bufnr)
    assert.equals(1, direct_requests)
    assert.equals(0, cache_reads)
  end)

  it('rejects a completed request from before the latest edit', function()
    request_event('pending', 1)
    vim.api.nvim_buf_set_lines(bufnr, 2, -1, false, { '// changed' })
    local seq = unused_refs_states[bufnr].refresh_seq
    request_event('complete', 1)
    assert.equals(seq, unused_refs_states[bufnr].refresh_seq)
    assert.equals(0, cache_reads)
  end)

  it('consumes overlapping shared responses for the same buffer version', function()
    request_event('pending', 1)
    request_event('pending', 2)
    request_event('complete', 1)
    cache_unused_lens()
    assert.is_true(vim.wait(300, function()
      return cache_reads == 2
    end, 10))
    assert_unused_reference_hint(bufnr)

    request_event('complete', 2)
    cached_lenses = {}
    assert.is_true(vim.wait(300, function()
      return cache_reads == 4
    end, 10))
    assert.same({}, get_unused_reference_diagnostics(bufnr))
    assert.equals(0, direct_requests)
  end)

  it('falls back when a shared completion leaves the old cache unchanged', function()
    -- The native CodeLens handler leaves old cached lenses untouched on an error.
    request_event('pending', 1)
    request_event('complete', 1)
    assert.is_true(vim.wait(1200, function()
      return direct_requests > 0
    end, 20))
    assert.same({}, get_unused_reference_diagnostics(bufnr))
  end)

  it('accepts an empty shared result when the old cache had lenses', function()
    request_event('pending', 1)
    request_event('complete', 1)
    cached_lenses = {}
    assert.is_true(vim.wait(300, function()
      return cache_reads == 2
    end, 10))
    assert.equals(0, direct_requests)
    assert.same({}, get_unused_reference_diagnostics(bufnr))
  end)
end)
