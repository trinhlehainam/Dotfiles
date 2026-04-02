local php = require('configs.lsp.php')

local Methods = vim.lsp.protocol.Methods
local config = php.lspconfigs[1].config

-- This spec intentionally reaches into php.lua through named upvalues so it
-- can exercise the real diagnostic helper without widening the runtime API.
-- It is coupled to php.lua's private closure graph, not upvalue order: simple
-- reordering is fine, but refactors that stop capturing these helpers will
-- need to update this test.
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

local schedule_unused_reference_refresh =
  get_upvalue(config.on_attach, 'schedule_unused_reference_refresh')
local refresh_unused_reference_diagnostics_from_cache =
  get_upvalue(schedule_unused_reference_refresh, 'refresh_unused_reference_diagnostics_from_cache')
local set_unused_reference_diagnostics =
  get_upvalue(refresh_unused_reference_diagnostics_from_cache, 'set_unused_reference_diagnostics')

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

  before_each(function()
    requests = { resolve = 0 }

    client = {
      id = 9901,
      name = 'intelephense',
      offset_encoding = 'utf-16',
    }

    function client:supports_method(method)
      return method == Methods.codeLens_resolve
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

  it('restores the unused-reference hint after delete and restore when fallback lenses require resolve', function()
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
  end)
end)
