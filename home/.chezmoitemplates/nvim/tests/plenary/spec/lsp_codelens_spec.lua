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
  local buffers
  local clients

  before_each(function()
    original_get_client_by_id = vim.lsp.get_client_by_id
    buffers = {}
    clients = {}

    vim.lsp.get_client_by_id = function(id)
      return clients[id]
    end
  end)

  after_each(function()
    vim.lsp.get_client_by_id = original_get_client_by_id

    for _, bufnr in ipairs(buffers) do
      codelens.detach_all(bufnr)
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
    end
  end)

  it('renders above-line virtual text aggregated across clients by default', function()
    local bufnr = make_buf({ 'local value = 1', 'return value' })
    table.insert(buffers, bufnr)

    clients[1] = {
      id = 1,
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

    codelens.attach(clients[1], bufnr)
    codelens.attach(clients[2], bufnr)

    wait_for('expected aggregated codelens render', function()
      local rows = get_rendered_rows(bufnr)
      return rows[0]
        and rows[0].placement == 'above'
        and rows[0].text == '3 References | 1 Implementation'
        and rows[1]
        and rows[1].placement == 'above'
        and rows[1].text == 'Run Test'
    end)
  end)

  it('switches placement from above to eol and back without new requests', function()
    local bufnr = make_buf({ 'local value = 1' })
    table.insert(buffers, bufnr)

    local request_count = 0
    clients[1] = {
      id = 1,
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

    codelens.attach(clients[1], bufnr)

    wait_for('expected default above-line codelens', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'above' and row.text == 'Lens Title'
    end)
    assert.equals(1, request_count)

    codelens.set_context(bufnr, 'diffview', 'eol')

    wait_for('expected eol codelens override', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'eol' and row.text == '  Lens Title'
    end)
    assert.equals(1, request_count)

    codelens.clear_context(bufnr, 'diffview')

    wait_for('expected above-line codelens after clearing override', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'above' and row.text == 'Lens Title'
    end)
    assert.equals(1, request_count)
  end)

  it('clears while editing and ignores stale responses from older refreshes', function()
    local bufnr = make_buf({ 'local value = 1' })
    table.insert(buffers, bufnr)

    local request_count = 0
    local first_callback

    clients[1] = {
      id = 1,
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

    codelens.attach(clients[1], bufnr)

    vim.api.nvim_exec_autocmds('InsertEnter', { buffer = bufnr })
    assert.same({}, get_rendered_rows(bufnr))

    vim.api.nvim_exec_autocmds('InsertLeave', { buffer = bufnr })

    wait_for('expected fresh codelens after insert leave', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'above' and row.text == 'Fresh Lens'
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
    assert.same({ placement = 'above', text = 'Fresh Lens' }, row)
  end)

  it('resolves unresolved lenses before rendering their titles', function()
    local bufnr = make_buf({ 'function demo() end' })
    table.insert(buffers, bufnr)

    clients[1] = {
      id = 1,
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

    codelens.attach(clients[1], bufnr)

    wait_for('expected resolved codelens title', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'above' and row.text == 'Resolved Lens'
    end)
  end)

  it('cleans up extmarks and autocmds when the last client detaches', function()
    local bufnr = make_buf({ 'return 1' })
    table.insert(buffers, bufnr)

    clients[1] = {
      id = 1,
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

    codelens.attach(clients[1], bufnr)

    wait_for('expected initial codelens render', function()
      local row = get_rendered_rows(bufnr)[0]
      return row and row.placement == 'above' and row.text == 'Detached Lens'
    end)

    codelens.detach(bufnr, 1)

    assert.same({}, get_rendered_rows(bufnr))
    assert.same({}, vim.api.nvim_get_autocmds({ group = augroup, buffer = bufnr }))
  end)
end)
