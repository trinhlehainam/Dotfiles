describe('LSP buffer features', function()
  local module_names = { 'configs.plugins.nvim-lspconfig', 'configs.lsp', 'codesettings' }
  local group_names = {
    'kickstart-lsp-attach',
    'kickstart-lsp-detach',
    'kickstart-lsp-highlight',
  }
  local original_modules
  local original
  local buffers
  local clients
  local hint_states

  local function make_buf()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'local value = 1' })
    buffers[#buffers + 1] = bufnr
    return bufnr
  end

  local function add_client(id, method)
    clients[id] = {
      id = id,
      supports_method = function(_, requested)
        return requested == method
      end,
    }
  end

  local function emit(event, bufnr, client_id)
    vim.api.nvim_exec_autocmds(event, {
      group = event == 'LspAttach' and 'kickstart-lsp-attach' or 'kickstart-lsp-detach',
      buffer = bufnr,
      data = { client_id = client_id },
    })
  end

  local function highlight_autocmds(bufnr)
    return vim.api.nvim_get_autocmds({ group = 'kickstart-lsp-highlight', buffer = bufnr })
  end

  local function add_reference(bufnr)
    vim.lsp.util.buf_highlight_references(bufnr, {
      {
        range = {
          start = { line = 0, character = 6 },
          ['end'] = { line = 0, character = 11 },
        },
      },
    }, 'utf-16')
  end

  local function references(bufnr)
    local namespace = vim.api.nvim_get_namespaces()['nvim.lsp.references']
    return vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
  end

  before_each(function()
    buffers = {}
    clients = {}
    hint_states = {}
    original_modules = {}
    for _, name in ipairs(module_names) do
      original_modules[name] = package.loaded[name]
      package.loaded[name] = nil
    end

    original = {
      get_client_by_id = vim.lsp.get_client_by_id,
      get_clients = vim.lsp.get_clients,
      config = vim.lsp.config,
      codelens_enable = vim.lsp.codelens.enable,
      diagnostic_config = vim.diagnostic.config,
      keymap_set = vim.keymap.set,
      current_buf = vim.api.nvim_get_current_buf(),
      hints_enabled = vim.lsp.inlay_hint.is_enabled(),
    }
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      hint_states[bufnr] = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
    end

    vim.lsp.get_client_by_id = function(id)
      return clients[id]
    end
    vim.lsp.get_clients = function()
      return {}
    end
    vim.lsp.config = setmetatable({}, { __call = function() end })
    vim.lsp.codelens.enable = function() end
    vim.diagnostic.config = function() end
    vim.keymap.set = function(mode, lhs, rhs, opts)
      if opts and opts.buffer then
        original.keymap_set(mode, lhs, rhs, opts)
      end
    end

    package.loaded['configs.lsp'] = { servers = {} }
    package.loaded['codesettings'] = {
      loader = function()
        return {
          config_file_paths = function(self)
            return self
          end,
          root_dir = function(self)
            return self
          end,
          with_local_settings = function() end,
        }
      end,
    }
    require('configs.plugins.nvim-lspconfig')
  end)

  after_each(function()
    for _, group in ipairs(group_names) do
      pcall(vim.api.nvim_del_augroup_by_name, group)
    end
    vim.lsp.inlay_hint.enable(original.hints_enabled)
    for bufnr, enabled in pairs(hint_states) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.lsp.inlay_hint.enable(enabled, { bufnr = bufnr })
      end
    end
    vim.api.nvim_set_current_buf(original.current_buf)
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end

    vim.lsp.get_client_by_id = original.get_client_by_id
    vim.lsp.get_clients = original.get_clients
    vim.lsp.config = original.config
    vim.lsp.codelens.enable = original.codelens_enable
    vim.diagnostic.config = original.diagnostic_config
    vim.keymap.set = original.keymap_set
    for _, name in ipairs(module_names) do
      package.loaded[name] = original_modules[name]
    end
  end)

  it('cleans up highlights when the final client has a sparse numeric ID', function()
    local bufnr = make_buf()
    add_client(7, vim.lsp.protocol.Methods.textDocument_documentHighlight)

    emit('LspAttach', bufnr, 7)
    assert.equals(4, #highlight_autocmds(bufnr))

    emit('LspDetach', bufnr, 7)
    assert.same({}, highlight_autocmds(bufnr))
    assert.is_nil(vim.b[bufnr].lsp_highlight_clients)
  end)

  it('keeps highlights until final detach and avoids duplicate callbacks on reattach', function()
    local bufnr = make_buf()
    add_client(2, vim.lsp.protocol.Methods.textDocument_documentHighlight)
    add_client(5, vim.lsp.protocol.Methods.textDocument_documentHighlight)

    emit('LspAttach', bufnr, 2)
    emit('LspAttach', bufnr, 5)
    assert.equals(4, #highlight_autocmds(bufnr))

    emit('LspDetach', bufnr, 2)
    assert.equals(4, #highlight_autocmds(bufnr))
    emit('LspDetach', bufnr, 5)
    assert.same({}, highlight_autocmds(bufnr))

    emit('LspAttach', bufnr, 2)
    emit('LspAttach', bufnr, 2)
    assert.equals(4, #highlight_autocmds(bufnr))
    emit('LspDetach', bufnr, 2)
    assert.same({}, highlight_autocmds(bufnr))
  end)

  it('toggles inlay hints only in the buffer owning the keymap', function()
    local bufnr = make_buf()
    local other_buf = make_buf()
    add_client(7, vim.lsp.protocol.Methods.textDocument_inlayHint)
    emit('LspAttach', bufnr, 7)
    vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
    vim.lsp.inlay_hint.enable(false, { bufnr = other_buf })

    local toggle
    for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, 'n')) do
      if keymap.desc == 'LSP: [T]oggle Inlay [H]ints' then
        toggle = keymap.callback
      end
    end
    assert.is_function(toggle)
    toggle()

    assert.is_true(vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }))
    assert.is_false(vim.lsp.inlay_hint.is_enabled({ bufnr = other_buf }))
    toggle()
    assert.is_false(vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }))
  end)

  it('clears detached buffer references while preserving another current buffer', function()
    local bufnr = make_buf()
    local other_buf = make_buf()
    add_client(1, vim.lsp.protocol.Methods.textDocument_documentHighlight)
    emit('LspAttach', bufnr, 1)
    vim.api.nvim_set_current_buf(other_buf)
    add_reference(bufnr)
    add_reference(other_buf)
    assert.equals(1, #references(bufnr))
    assert.equals(1, #references(other_buf))

    emit('LspDetach', bufnr, 1)

    assert.same({}, references(bufnr))
    assert.equals(1, #references(other_buf))
    assert.equals(other_buf, vim.api.nvim_get_current_buf())
  end)
end)
