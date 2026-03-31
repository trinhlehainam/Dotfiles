local codelens = require('utils.lsp_codelens')

local Methods = vim.lsp.protocol.Methods
local namespace = 'dotfiles.lsp.codelens'
local augroup = 'dotfiles-lsp-codelens'

local function wait_for(message, predicate, timeout)
  local ok = vim.wait(timeout or 1000, function()
    local status, done = pcall(predicate)
    return status and done
  end, 10, false)

  if not ok then
    error(message)
  end
end

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function join_chunks(chunks)
  local parts = {}

  for _, chunk in ipairs(chunks or {}) do
    parts[#parts + 1] = chunk[1]
  end

  return table.concat(parts)
end

local function get_rendered_rows(bufnr)
  local ns = vim.api.nvim_get_namespaces()[namespace]
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
  local rows = {}

  for _, extmark in ipairs(extmarks) do
    local details = extmark[4]
    if details.virt_text then
      rows[extmark[2]] = {
        placement = 'eol',
        text = join_chunks(details.virt_text),
      }
    elseif details.virt_lines and details.virt_lines[1] then
      rows[extmark[2]] = {
        placement = 'above',
        text = join_chunks(details.virt_lines[1]),
      }
    end
  end

  return rows
end

describe('utils.lsp_codelens', function()
  local original_get_client_by_id
  local original_get_clients
  local original_enable
  local buffers
  local clients
  local enable_calls

  before_each(function()
    original_get_client_by_id = vim.lsp.get_client_by_id
    original_get_clients = vim.lsp.get_clients
    original_enable = vim.lsp.codelens.enable

    buffers = {}
    clients = {}
    enable_calls = {}

    vim.lsp.get_client_by_id = function(id)
      return clients[id]
    end

    vim.lsp.get_clients = function(filter)
      local bufnr = filter and filter.bufnr or nil
      local matched = {}

      for _, client in pairs(clients) do
        if bufnr == nil or client._bufnr == bufnr then
          matched[#matched + 1] = client
        end
      end

      table.sort(matched, function(a, b)
        return a.id < b.id
      end)
      return matched
    end

    vim.lsp.codelens.enable = function(enable, filter)
      enable_calls[#enable_calls + 1] = {
        enable = enable,
        bufnr = filter and filter.bufnr or nil,
      }
    end
  end)

  after_each(function()
    vim.lsp.get_client_by_id = original_get_client_by_id
    vim.lsp.get_clients = original_get_clients
    vim.lsp.codelens.enable = original_enable

    for _, bufnr in ipairs(buffers) do
      codelens.detach_all(bufnr)
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
    end
  end)

  it('renders eol virtual text aggregated across clients when a context is active', function()
    local bufnr = make_buf({ 'local value = 1', 'return value' })
    table.insert(buffers, bufnr)

    clients[1] = {
      id = 1,
      _bufnr = bufnr,
      offset_encoding = 'utf-16',
      supports_method = function(_, method)
        return method == Methods.textDocument_codeLens
      end,
      request = function(_, _, _, callback)
        callback(nil, {
          {
            range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
            command = { title = '3 References' },
          },
        })
      end,
    }

    clients[2] = {
      id = 2,
      _bufnr = bufnr,
      offset_encoding = 'utf-16',
      supports_method = function(_, method)
        return method == Methods.textDocument_codeLens
      end,
      request = function(_, _, _, callback)
        callback(nil, {
          {
            range = { start = { line = 0, character = 6 }, ['end'] = { line = 0, character = 6 } },
            command = { title = '1 Implementation' },
          },
          {
            range = { start = { line = 1, character = 0 }, ['end'] = { line = 1, character = 0 } },
            command = { title = 'Run Test' },
          },
        })
      end,
    }

    codelens.set_context(bufnr, 'diffview', 'eol')

    wait_for('expected aggregated eol codelens render', function()
      local rows = get_rendered_rows(bufnr)
      return rows[0]
        and rows[0].placement == 'eol'
        and rows[0].text == '  3 References | 1 Implementation'
        and rows[1]
        and rows[1].placement == 'eol'
        and rows[1].text == '  Run Test'
    end)

    assert.same({
      {
        enable = false,
        bufnr = bufnr,
      },
    }, enable_calls)
  end)

  it('stacks contexts without new requests and re-enables built-in codelens on final clear', function()
    local bufnr = make_buf({ 'local value = 1' })
    table.insert(buffers, bufnr)

    local request_count = 0
    clients[1] = {
      id = 1,
      _bufnr = bufnr,
      offset_encoding = 'utf-16',
      supports_method = function(_, method)
        return method == Methods.textDocument_codeLens
      end,
      request = function(_, _, _, callback)
        request_count = request_count + 1
        callback(nil, {
          {
            range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
            command = { title = 'Lens Title' },
          },
        })
      end,
    }

    codelens.set_context(bufnr, 'diffview', 'eol')

    wait_for('expected initial eol codelens', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'eol' and row.text == '  Lens Title'
    end)
    assert.equals(1, request_count)

    codelens.set_context(bufnr, 'gitsigns_blame', 'eol')
    local row = get_rendered_rows(bufnr)[0]
    assert.same({ placement = 'eol', text = '  Lens Title' }, row)
    assert.equals(1, request_count)
    assert.same({
      {
        enable = false,
        bufnr = bufnr,
      },
    }, enable_calls)

    codelens.clear_context(bufnr, 'diffview')
    row = get_rendered_rows(bufnr)[0]
    assert.same({ placement = 'eol', text = '  Lens Title' }, row)
    assert.equals(1, request_count)
    assert.same({
      {
        enable = false,
        bufnr = bufnr,
      },
    }, enable_calls)

    codelens.clear_context(bufnr, 'gitsigns_blame')

    assert.same({}, get_rendered_rows(bufnr))
    assert.same({
      {
        enable = false,
        bufnr = bufnr,
      },
      {
        enable = true,
        bufnr = bufnr,
      },
    }, enable_calls)
  end)

  it('clears while editing and ignores stale responses from older refreshes', function()
    local bufnr = make_buf({ 'local value = 1' })
    table.insert(buffers, bufnr)

    local request_count = 0
    local first_callback

    clients[1] = {
      id = 1,
      _bufnr = bufnr,
      offset_encoding = 'utf-16',
      supports_method = function(_, method)
        return method == Methods.textDocument_codeLens
      end,
      request = function(_, _, _, callback)
        request_count = request_count + 1
        if request_count == 1 then
          first_callback = callback
          return
        end

        callback(nil, {
          {
            range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
            command = { title = 'Fresh Lens' },
          },
        })
      end,
    }

    codelens.set_context(bufnr, 'diffview', 'eol')

    vim.api.nvim_exec_autocmds('InsertEnter', { buffer = bufnr })
    assert.same({}, get_rendered_rows(bufnr))

    vim.api.nvim_exec_autocmds('InsertLeave', { buffer = bufnr })

    wait_for('expected fresh codelens after insert leave', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'eol' and row.text == '  Fresh Lens'
    end)

    first_callback(nil, {
      {
        range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
        command = { title = 'Stale Lens' },
      },
    })

    vim.wait(50, function()
      return false
    end, 10, false)

    local row = get_rendered_rows(bufnr)[0]
    assert.same({ placement = 'eol', text = '  Fresh Lens' }, row)
  end)

  it('resolves unresolved lenses before rendering their titles', function()
    local bufnr = make_buf({ 'function demo() end' })
    table.insert(buffers, bufnr)

    clients[1] = {
      id = 1,
      _bufnr = bufnr,
      offset_encoding = 'utf-16',
      supports_method = function(_, method)
        return method == Methods.textDocument_codeLens or method == Methods.codeLens_resolve
      end,
      request = function(_, method, params, callback)
        if method == Methods.textDocument_codeLens then
          callback(nil, {
            {
              range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
              data = { id = 'unresolved' },
            },
          })
          return
        end

        assert.same({ id = 'unresolved' }, params.data)
        vim.schedule(function()
          callback(
            nil,
            vim.tbl_deep_extend('force', params, {
              command = { title = 'Resolved Lens' },
            })
          )
        end)
      end,
    }

    codelens.set_context(bufnr, 'diffview', 'eol')

    wait_for('expected resolved codelens title', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'eol' and row.text == '  Resolved Lens'
    end)
  end)

  it('cleans up extmarks and autocmds when the final context clears', function()
    local bufnr = make_buf({ 'return 1' })
    table.insert(buffers, bufnr)

    clients[1] = {
      id = 1,
      _bufnr = bufnr,
      offset_encoding = 'utf-16',
      supports_method = function(_, method)
        return method == Methods.textDocument_codeLens
      end,
      request = function(_, _, _, callback)
        callback(nil, {
          {
            range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
            command = { title = 'Detached Lens' },
          },
        })
      end,
    }

    codelens.set_context(bufnr, 'diffview', 'eol')

    wait_for('expected initial codelens render', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'eol' and row.text == '  Detached Lens'
    end)

    codelens.clear_context(bufnr, 'diffview')

    assert.same({}, get_rendered_rows(bufnr))
    assert.same({}, vim.api.nvim_get_autocmds({ group = augroup, buffer = bufnr }))
    assert.same({
      {
        enable = false,
        bufnr = bufnr,
      },
      {
        enable = true,
        bufnr = bufnr,
      },
    }, enable_calls)
  end)
end)
