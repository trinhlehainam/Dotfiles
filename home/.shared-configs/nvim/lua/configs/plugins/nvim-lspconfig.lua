-- LSP buffer-local setup (keymaps, highlights, inlay hints)
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    -- Helper for buffer-local LSP keymaps
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    map('grr', function()
      Snacks.picker.lsp_references()
    end, '[G]oto [R]eferences')

    map('gri', function()
      Snacks.picker.lsp_implementations()
    end, '[G]oto [I]mplementation')

    map('grd', function()
      Snacks.picker.lsp_definitions()
    end, '[G]oto [D]efinition')

    -- Declaration (not definition)
    map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    map('gO', function()
      Snacks.picker.lsp_symbols()
    end, 'Open Document Symbols')

    map('gW', function()
      Snacks.picker.lsp_workspace_symbols()
    end, 'Open Workspace Symbols')

    map('grt', function()
      Snacks.picker.lsp_type_definitions()
    end, '[G]oto [T]ype Definition')

    -- Document highlights on CursorHold
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if
      client
      and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
    then
      -- String keys preserve a set through vim.b's Vimscript conversion.
      local highlight_clients = vim.b[event.buf].lsp_highlight_clients or {}
      local first_client = next(highlight_clients) == nil
      highlight_clients[tostring(client.id)] = true
      vim.b[event.buf].lsp_highlight_clients = highlight_clients

      -- Only create autocmds once per buffer (first highlight-capable client)
      if first_client then
        local highlight_augroup =
          vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })
      end
    end

    -- Inlay hints toggle (if supported)
    if
      client
      and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf)
    then
      map('<leader>th', function()
        local filter = { bufnr = event.buf }
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
      end, '[T]oggle Inlay [H]ints')
    end
  end,
})

-- Cleanup on LspDetach - only disable features when no remaining client supports them
vim.api.nvim_create_autocmd('LspDetach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
  callback = function(event)
    local bufnr = event.buf
    local client_id = tostring(event.data.client_id)

    -- Remove from highlight clients and cleanup if none remain (vim.b returns copies, must reassign)
    local highlight_clients = vim.b[bufnr].lsp_highlight_clients
    if highlight_clients and highlight_clients[client_id] then
      highlight_clients[client_id] = nil
      if next(highlight_clients) == nil then
        vim.lsp.util.buf_clear_references(bufnr)
        pcall(vim.api.nvim_clear_autocmds, { group = 'kickstart-lsp-highlight', buffer = bufnr })
        vim.b[bufnr].lsp_highlight_clients = nil
      else
        vim.b[bufnr].lsp_highlight_clients = highlight_clients
      end
    end
  end,
})

-- Enable built-in CodeLens globally; explicit git contexts opt out per-buffer.
vim.lsp.codelens.enable(true)

vim.diagnostic.config({
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = false,
  virtual_lines = {
    current_line = true,
  },
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float({ bufnr = bufnr, scope = 'cursor', focus = false })
    end,
  },
})

-- Diagnostic keymaps

-- Toggle diagnostic virtual_lines
vim.keymap.set('n', 'gK', function()
  local new_config = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = new_config })
end, { desc = 'Toggle diagnostic virtual_lines' })

vim.keymap.set('n', 'gk', function()
  local current = vim.diagnostic.config().virtual_lines
  if not current then
    vim.notify('diagnostic virtual_lines is disabled (toggle with gK)', vim.log.levels.WARN)
    return
  end

  local current_line = type(current) == 'table' and current.current_line or false
  vim.diagnostic.config({ virtual_lines = { current_line = not current_line } })
end, { desc = 'Toggle diagnostic virtual_lines current_line' })

vim.keymap.set(
  'n',
  '<leader>e',
  vim.diagnostic.open_float,
  { desc = 'Open floating diagnostic message' }
)

local codesettings = require('codesettings')

local function load_project_settings(_, config)
  codesettings.loader():root_dir(config.root_dir):with_local_settings(config.name, config)
end

vim.lsp.config('*', { before_init = load_project_settings })

local servers = {}
for name, config in vim.spairs(require('configs.lsp').servers) do
  vim.lsp.config(name, config)

  -- Server hooks override the wildcard hook. Compose them so native initialization
  -- still runs and project settings have the final say.
  local before_init = vim.lsp.config[name].before_init
  if before_init ~= load_project_settings then
    vim.lsp.config(name, {
      before_init = function(params, resolved_config)
        before_init(params, resolved_config)
        load_project_settings(params, resolved_config)
      end,
    })
  end
  table.insert(servers, name)
end

-- Configure the entire registry before enabling clients for already-open buffers.
vim.lsp.enable(servers)
