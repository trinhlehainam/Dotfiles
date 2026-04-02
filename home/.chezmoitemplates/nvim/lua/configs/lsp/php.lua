-- PHP LSP config (Intelephense)
-- Ref: https://github.com/bmewburn/intelephense-docs

local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local log = require('utils.log')

local M = LanguageSetting:new()

-- Treesitter
M.treesitter.filetypes = { 'php' }

-- Formatters
M.formatterconfig.mason_packages = { 'blade-formatter', 'php-cs-fixer' }
M.formatterconfig.formatters_by_ft = {
  blade = { 'blade-formatter' },
  php = { 'php_cs_fixer' },
}

-- Linters
M.linterconfig.mason_packages = { 'phpstan', 'phpcs' }
M.linterconfig.linters_by_ft = { php = { 'phpstan', 'phpcs' } }
M.linterconfig.lint_on_save = false

-- Intelephense LSP
local intelephense = LspConfig:new('intelephense', 'intelephense')

-- Constants
local CACHE_PATH = vim.fn.stdpath('cache') .. '/intelephense'
local STOP_TIMEOUT = 5000
local POLL_INTERVAL = 50

local CMD = {
  INDEX = 'IntelephenseIndexWorkspace',
  CANCEL = 'IntelephenseCancelIndexing',
  STATUS = 'IntelephenseStatus',
}

-- State
local commands_registered = false
local indexing_in_progress = false
local active_clients = {}

local function get_client()
  return vim.lsp.get_clients({ name = 'intelephense' })[1]
end

-- Register user commands
local function register_commands_once()
  if commands_registered then
    return
  end

  -- :IntelephenseIndexWorkspace - reindex (! = clear cache)
  vim.api.nvim_create_user_command(CMD.INDEX, function(opts)
    local clear_cache = opts.bang

    if not clear_cache and indexing_in_progress then
      log.info('Indexing in progress.', 'Intelephense')
      return
    end

    local client = get_client()
    if not client then
      log.warn('Intelephense is not running in this workspace.', 'Intelephense')
      return
    end

    local root_dir = client.config.root_dir
    -- Prefer a graceful shutdown here: forcing termination while the server is
    -- writing cache/index files risks corruption. The explicit false keeps this
    -- behavior independent of any future client exit_timeout setting.
    client:stop(false)

    local stopped = vim.wait(STOP_TIMEOUT, function()
      return client:is_stopped()
    end, POLL_INTERVAL)

    if not stopped then
      log.error('Could not stop Intelephense before reindexing.', 'Intelephense')
      return
    end

    -- Restart with resolved config, preserving handlers/on_attach
    local base_config = vim.lsp.config['intelephense'] or {}
    vim.lsp.start(vim.tbl_deep_extend('force', base_config, {
      root_dir = root_dir,
      init_options = {
        storagePath = CACHE_PATH,
        clearCache = clear_cache or nil,
      },
    }))

    if clear_cache then
      log.info('Full reindex requested (cache clear enabled).', 'Intelephense')
    else
      log.info('Incremental reindex requested.', 'Intelephense')
    end
  end, { bang = true, desc = 'Intelephense: Reindex (! clears cache)' })

  -- :IntelephenseStatus - show status
  vim.api.nvim_create_user_command(CMD.STATUS, function()
    local client = get_client()
    if not client then
      log.warn('Intelephense is not running in this workspace.', 'Intelephense')
      return
    end

    local status = indexing_in_progress and 'Indexing in progress' or 'Ready'
    log.info('Status: ' .. status .. ' | Cache: ' .. CACHE_PATH, 'Intelephense')
  end, { desc = 'Intelephense: Show status' })

  commands_registered = true
end

local function unregister_commands()
  vim.schedule(function()
    -- Defer to avoid calling nvim_del_user_command in a fast event context
    pcall(vim.api.nvim_del_user_command, CMD.INDEX)
    pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
    pcall(vim.api.nvim_del_user_command, CMD.STATUS)
  end)

  commands_registered = false
  indexing_in_progress = false
end

-- Indexing started handler
local function on_indexing_started()
  if indexing_in_progress then
    return
  end

  indexing_in_progress = true

  -- Register cancel command (only available during indexing)
  if vim.fn.exists(':' .. CMD.CANCEL) == 0 then
    vim.api.nvim_create_user_command(CMD.CANCEL, function()
      local client = get_client()
      if not client then
        log.warn('Intelephense is not running in this workspace.', 'Intelephense')
        return
      end

      client:request('cancelIndexing', {}, function(err)
        if err then
          log.error('Failed to cancel indexing: ' .. tostring(err), 'Intelephense')
        else
          indexing_in_progress = false
          pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
          log.info('Indexing canceled by user.', 'Intelephense')
        end
      end, 0)
    end, { desc = 'Intelephense: Cancel indexing' })
  end

  log.info('Indexing started.', 'Intelephense')
end

-- Indexing ended handler
local function on_indexing_ended()
  indexing_in_progress = false
  pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
  log.info('Indexing finished.', 'Intelephense')
end

-- ============================================================================
-- Unused Function Diagnostics (via Intelephense CodeLens)
-- ============================================================================
local unused_refs_ns = vim.api.nvim_create_namespace('intelephense_unused_refs')
local unused_refs_augroup =
  vim.api.nvim_create_augroup('intelephense-unused-refs', { clear = false })

-- Extract symbol name from buffer at position
local function get_symbol_at(bufnr, line, col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)
  if not lines[1] then
    return nil
  end
  -- Extract word at column (handles $var, function names, class names)
  local text = lines[1]:sub(col + 1)
  return text:match('^%$?[%w_]+')
end

local function set_unused_reference_diagnostics(bufnr, client_id, lenses)
  -- Lines with existing intelephense diagnostics
  local existing =
    vim.diagnostic.get(bufnr, { namespace = vim.lsp.diagnostic.get_namespace(client_id) })
  local diag_lines = vim.iter(existing):fold({}, function(acc, d)
    acc[d.lnum] = true
    return acc
  end)
  local has_existing = next(diag_lines) ~= nil

  -- Single pass: filter + map in one fold (3x fewer function calls)
  local diagnostics = vim.iter(lenses or {}):fold({}, function(acc, lens)
    local cmd = lens.command
    if cmd and cmd.title and cmd.title:match('^0 References') then
      local pos = lens.range.start
      if not has_existing or not diag_lines[pos.line] then
        local symbol = get_symbol_at(bufnr, pos.line, pos.character) or 'symbol'
        acc[#acc + 1] = {
          lnum = pos.line,
          col = pos.character,
          message = ("Symbol '%s' is declared but not used."):format(symbol),
          severity = vim.diagnostic.severity.HINT,
          source = 'intelephense',
          code = 'P1003',
        }
      end
    end
    return acc
  end)

  vim.diagnostic.set(unused_refs_ns, bufnr, diagnostics)
end

local function refresh_unused_reference_diagnostics(client, bufnr)
  if
    client.name ~= 'intelephense'
    or not vim.api.nvim_buf_is_valid(bufnr)
    or not client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens, bufnr)
  then
    return
  end

  -- Request CodeLens directly so these hint diagnostics do not depend on which
  -- renderer currently owns CodeLens output for the buffer.
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  client:request(vim.lsp.protocol.Methods.textDocument_codeLens, params, function(err, result)
    if err or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if vim.api.nvim_buf_get_changedtick(bufnr) ~= tick then
      return
    end

    set_unused_reference_diagnostics(bufnr, client.id, result)
  end, bufnr)
end

local function register_unused_reference_autocmd_once(bufnr)
  if vim.b[bufnr].intelephense_unused_refs_autocmd then
    return
  end

  vim.b[bufnr].intelephense_unused_refs_autocmd = true
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufWritePost' }, {
    buffer = bufnr,
    group = unused_refs_augroup,
    callback = function()
      local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'intelephense' })[1]
      if client then
        refresh_unused_reference_diagnostics(client, bufnr)
      end
    end,
  })
end

local function has_active_client_in_buffer(bufnr)
  for _, active_bufnr in pairs(active_clients) do
    if active_bufnr == bufnr then
      return true
    end
  end

  return false
end

intelephense.config = {
  init_options = { storagePath = CACHE_PATH },

  settings = {
    intelephense = {
      codeLens = {
        references = { enable = true },
        implementations = { enable = true },
        usages = { enable = true },
        overrides = { enable = true },
        parent = { enable = true },
      },
    },
  },

  -- Intelephense indexing notification handlers
  handlers = {
    ['indexingStarted'] = on_indexing_started,
    ['indexingEnded'] = on_indexing_ended,
  },

  on_attach = function(client, bufnr)
    active_clients[client.id] = bufnr
    if client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens, bufnr) then
      register_unused_reference_autocmd_once(bufnr)
      refresh_unused_reference_diagnostics(client, bufnr)
    end
    register_commands_once()
  end,

  -- LSP on_exit may run in a fast event; schedule all editor-state cleanup.
  on_exit = vim.schedule_wrap(function(_, _, client_id)
    local bufnr = active_clients[client_id]
    active_clients[client_id] = nil

    if bufnr and not has_active_client_in_buffer(bufnr) then
      pcall(vim.api.nvim_clear_autocmds, { group = unused_refs_augroup, buffer = bufnr })
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].intelephense_unused_refs_autocmd = nil
        vim.diagnostic.set(unused_refs_ns, bufnr, {})
      end
    end

    if next(active_clients) == nil then
      unregister_commands()
    end
  end),
}

M.lspconfigs = { intelephense }

-- DAP
M.dapconfigs = {
  { type = 'php', use_masondap_default_setup = true },
}

-- Neotest
M.neotest_adapter_setup = function()
  local ok, adapter = pcall(require, 'neotest-phpunit')
  return ok and adapter or nil
end

return M
