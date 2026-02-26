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

    ---@param client vim.lsp.Client
    ---@param method vim.lsp.protocol.Method
    ---@param bufnr? integer some lsp support methods only in specific files
    ---@return boolean
    local function client_supports_method(client, method, bufnr)
      return client:supports_method(method, bufnr)
    end

    -- Document highlights on CursorHold
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if
      client
      and client_supports_method(
        client,
        vim.lsp.protocol.Methods.textDocument_documentHighlight,
        event.buf
      )
    then
      -- Track this client as supporting highlights (vim.b returns copies, must reassign)
      local highlight_clients = vim.b[event.buf].lsp_highlight_clients or {}
      highlight_clients[client.id] = true
      vim.b[event.buf].lsp_highlight_clients = highlight_clients

      -- Only create autocmds once per buffer (first highlight-capable client)
      if vim.tbl_count(highlight_clients) == 1 then
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
      and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf)
    then
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
      end, '[T]oggle Inlay [H]ints')
    end

    -- CodeLens (if supported)
    -- TODO: When PR #36469 merges, add { display = { virt_lines = true } } for above-line display
    -- Track: https://github.com/neovim/neovim/pull/36469
    if
      client
      and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_codeLens, event.buf)
    then
      -- Track this client as supporting codelens (vim.b returns copies, must reassign)
      local codelens_clients = vim.b[event.buf].lsp_codelens_clients or {}
      codelens_clients[client.id] = true
      vim.b[event.buf].lsp_codelens_clients = codelens_clients

      vim.lsp.codelens.refresh({ bufnr = event.buf })

      -- Only create autocmds once per buffer (first codelens-capable client)
      if vim.tbl_count(codelens_clients) == 1 then
        local codelens_augroup = vim.api.nvim_create_augroup('lsp-codelens', { clear = false })
        vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufWritePost' }, {
          buffer = event.buf,
          group = codelens_augroup,
          callback = function()
            vim.lsp.codelens.refresh({ bufnr = event.buf })
          end,
        })
      end
    end
  end,
})

-- Cleanup on LspDetach - only disable features when no remaining client supports them
vim.api.nvim_create_autocmd('LspDetach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
  callback = function(event)
    local bufnr = event.buf
    local client_id = event.data.client_id

    -- Remove from highlight clients and cleanup if none remain (vim.b returns copies, must reassign)
    local highlight_clients = vim.b[bufnr].lsp_highlight_clients
    if highlight_clients and highlight_clients[client_id] then
      highlight_clients[client_id] = nil
      if next(highlight_clients) == nil then
        vim.lsp.buf.clear_references()
        pcall(vim.api.nvim_clear_autocmds, { group = 'kickstart-lsp-highlight', buffer = bufnr })
        vim.b[bufnr].lsp_highlight_clients = nil
      else
        vim.b[bufnr].lsp_highlight_clients = highlight_clients
      end
    end

    -- Remove from codelens clients and cleanup if none remain (vim.b returns copies, must reassign)
    local codelens_clients = vim.b[bufnr].lsp_codelens_clients
    if codelens_clients and codelens_clients[client_id] then
      codelens_clients[client_id] = nil
      if next(codelens_clients) == nil then
        pcall(vim.api.nvim_clear_autocmds, { group = 'lsp-codelens', buffer = bufnr })
        vim.lsp.codelens.clear(nil, bufnr)
        vim.b[bufnr].lsp_codelens_clients = nil
      else
        vim.b[bufnr].lsp_codelens_clients = codelens_clients
      end
    end
  end,
})

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
  -- TODO: Neovim 0.12+ jump.on_jump (see https://github.com/neovim/neovim/issues/33154)
  jump = { float = true },
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

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. Available keys are:
--  - cmd (table): Override the default command used to start the server
--  - filetypes (table): Override the default list of associated filetypes for the server
--  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
--  - settings (table): Override the default settings passed when initializing the server.
--        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
--- @type table<string, vim.lsp.Config>
local servers = {}

-- Safely load LSP configurations
local log = require('utils.log')
local lspconfigs = {}
local ok, lsp_config = pcall(require, 'configs.lsp')
if ok then
  lspconfigs = lsp_config.lspconfigs or {}
else
  log.warn('Failed to load configs.lsp module for lspconfig')
end

for _, lspconfig in pairs(lspconfigs) do
  local server_name = lspconfig.server
  -- Only add valid server configurations
  if type(server_name) == 'string' and server_name ~= '' then
    servers[server_name] = lspconfig.config
  end
end

-- Installed LSPs are configured and enabled automatically with mason-lspconfig
-- The loop below is for overriding the default configuration of LSPs with the ones in the servers table
for server_name, config in pairs(servers) do
  vim.lsp.enable(server_name)
  vim.lsp.config(server_name, config)
end

-- Language server for Postgres written in Rust
-- TODO: This framework is not production ready yet, check back later
-- lspconfig.postgres_lsp.setup{}
--
