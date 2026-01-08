-- PHP LSP config (Intelephense)
-- Ref: https://github.com/bmewburn/intelephense-docs

local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local log = require('utils.log')

local M = LanguageSetting:new()

-- Treesitter
M.treesitter.filetypes = { 'php' }

-- Formatters
M.formatterconfig.servers = { 'blade-formatter', 'php-cs-fixer' }
M.formatterconfig.formatters_by_ft = {
  blade = { 'blade-formatter' },
  php = { 'php_cs_fixer' },
}

-- Linters
M.linterconfig.servers = { 'phpstan' }
M.linterconfig.linters_by_ft = { php = { 'phpstan' } }

-- Intelephense LSP
local intelephense = LspConfig:new('intelephense', 'intelephense')

-- Constants
local CACHE_PATH = vim.fn.expand('~/.cache/intelephense')
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

local function get_client()
  return vim.lsp.get_clients({ name = 'intelephense' })[1]
end

-- Register user commands
local function register_commands()
  -- :IntelephenseIndexWorkspace - reindex (! = clear cache)
  vim.api.nvim_create_user_command(CMD.INDEX, function(opts)
    local client = get_client()
    if not client then
      log.warn('Intelephense not running', 'Intelephense')
      return
    end

    local clear_cache = opts.bang
    local root_dir = client.config.root_dir
    vim.lsp.stop_client(client.id)

    local stopped = vim.wait(STOP_TIMEOUT, function()
      return client:is_stopped()
    end, POLL_INTERVAL)

    if not stopped then
      log.error('Failed to stop client for reindex', 'Intelephense')
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

    local msg = clear_cache and 'Full reindex (cache cleared)...' or 'Incremental reindex...'
    log.info(msg, 'Intelephense')
  end, { bang = true, desc = 'Intelephense: Reindex (! clears cache)' })

  -- :IntelephenseStatus - show status
  vim.api.nvim_create_user_command(CMD.STATUS, function()
    local client = get_client()
    if not client then
      log.warn('Intelephense not running', 'Intelephense')
      return
    end

    local status = indexing_in_progress and 'Indexing...' or 'Ready'
    log.info(status .. ' | Cache: ' .. CACHE_PATH, 'Intelephense')
  end, { desc = 'Intelephense: Show status' })
end

local function unregister_commands()
  pcall(vim.api.nvim_del_user_command, CMD.INDEX)
  pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
  pcall(vim.api.nvim_del_user_command, CMD.STATUS)
end

-- Indexing started handler
local function on_indexing_started()
  indexing_in_progress = true

  -- Register cancel command (only available during indexing)
  vim.api.nvim_create_user_command(CMD.CANCEL, function()
    local client = get_client()
    if not client then
      log.warn('Intelephense not running', 'Intelephense')
      return
    end

    client:request('cancelIndexing', {}, function(err)
      if err then
        log.error('Failed to cancel: ' .. tostring(err), 'Intelephense')
      else
        log.info('Indexing cancelled', 'Intelephense')
      end
    end, 0)
  end, { desc = 'Intelephense: Cancel indexing' })

  log.info('Indexing started...', 'Intelephense')
end

-- Indexing ended handler
local function on_indexing_ended()
  indexing_in_progress = false
  pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
  log.info('Indexing complete', 'Intelephense')
end

intelephense.config = {
  init_options = { storagePath = CACHE_PATH },

  -- Indexing notification handlers (Neovim 0.11+ built-in handlers)
  handlers = {
    ['indexingStarted'] = on_indexing_started,
    ['indexingEnded'] = on_indexing_ended,
  },

  on_attach = function()
    if commands_registered then
      return
    end
    commands_registered = true
    register_commands()
  end,

  on_exit = function()
    unregister_commands()
    commands_registered = false
    indexing_in_progress = false
  end,
}

M.lspconfigs = { intelephense }

-- DAP
---@type custom.DapConfig
M.dapconfigs = {
  { type = 'php', use_masondap_default_setup = true },
}

-- Neotest
M.neotest_adapter_setup = function()
  local ok, adapter = pcall(require, 'neotest-phpunit')
  return ok and adapter or nil
end

return M
