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
local codelens_display_registered = false
local original_codelens_display
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
    vim.lsp.stop_client(client.id)

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

local function register_codelens_display_once()
  if codelens_display_registered then
    return
  end

  original_codelens_display = vim.lsp.codelens.display
  vim.lsp.codelens.display = function(lenses, bufnr, client_id)
    original_codelens_display(lenses, bufnr, client_id)

    local client = vim.lsp.get_client_by_id(client_id)
    if not client or client.name ~= 'intelephense' then
      return
    end

    vim.diagnostic.reset(unused_refs_ns, bufnr)
    if not lenses or #lenses == 0 then
      return
    end

    -- Lines with existing intelephense diagnostics
    local existing =
      vim.diagnostic.get(bufnr, { namespace = vim.lsp.diagnostic.get_namespace(client_id) })
    local diag_lines = vim.iter(existing):fold({}, function(acc, d)
      acc[d.lnum] = true
      return acc
    end)
    local has_existing = next(diag_lines) ~= nil

    -- Single pass: filter + map in one fold (3x fewer function calls)
    local diagnostics = vim.iter(lenses):fold({}, function(acc, lens)
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

  codelens_display_registered = true
end

local function unregister_codelens_display()
  if not codelens_display_registered then
    return
  end

  if original_codelens_display then
    vim.lsp.codelens.display = original_codelens_display
  end
  codelens_display_registered = false

  -- Schedule: diagnostic.reset uses buf API, unsafe in fast-event context
  vim.schedule(function()
    vim.diagnostic.reset(unused_refs_ns)
  end)
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

  on_attach = function(client, _)
    active_clients[client.id] = true
    register_codelens_display_once()
    register_commands_once()
  end,

  on_exit = function(_, _, client_id)
    active_clients[client_id] = nil
    if next(active_clients) == nil then
      unregister_codelens_display()
      unregister_commands()
    end
  end,
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
