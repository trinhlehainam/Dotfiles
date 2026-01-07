local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local log = require('utils.log')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'php' }

M.formatterconfig.servers = { 'blade-formatter', 'php-cs-fixer' }
M.formatterconfig.formatters_by_ft = {
  blade = { 'blade-formatter' },
  php = { 'php_cs_fixer' },
}

M.linterconfig.servers = { 'phpstan' }
M.linterconfig.linters_by_ft = {
  php = { 'phpstan' },
}

-- Intelephense with persistent cache and VSCode-matching commands
local intelephense = LspConfig:new('intelephense', 'intelephense')

---@type string XDG-compliant project cache path (globalStoragePath uses default ~/.intelephense)
local STORAGE_PATH = vim.fn.expand('~/.cache/intelephense')

---@enum IntelephenseCommand
local CMD = {
  INDEX_WORKSPACE = 'IntelephenseIndexWorkspace',
  CANCEL_INDEXING = 'IntelephenseCancelIndexing',
}

---@type boolean Local state management (no vim.g pollution)
local commands_registered = false

---Get the active Intelephense LSP client (single client per session assumed)
---@return vim.lsp.Client?
local function get_intelephense_client()
  return vim.lsp.get_clients({ name = 'intelephense' })[1]
end

---Register Intelephense user commands
---@return nil
local function register_commands()
  -- :IntelephenseIndexWorkspace  - Soft reindex (incremental, use existing cache)
  -- :IntelephenseIndexWorkspace! - Hard reindex (clear cache, full rebuild)
  vim.api.nvim_create_user_command(CMD.INDEX_WORKSPACE, function(opts)
    local client = get_intelephense_client()
    if not client then
      return log.warn('Intelephense not running', 'Intelephense')
    end

    local clear_cache = opts.bang
    local root_dir = client.config.root_dir
    vim.lsp.stop_client(client.id)

    -- Wait up to 5 seconds for client to stop, checking every 50ms
    local stopped, reason = vim.wait(5000, function()
      return client:is_stopped()
    end, 50)

    if not stopped then
      if reason == -1 then
        return log.error('Timed out waiting for client to stop', 'Intelephense')
      elseif reason == -2 then
        return log.warn('Restart interrupted', 'Intelephense')
      end
    end

    vim.lsp.start({
      name = 'intelephense',
      cmd = { 'intelephense', '--stdio' },
      root_dir = root_dir,
      init_options = {
        storagePath = STORAGE_PATH,
        clearCache = clear_cache or nil, -- nil = use existing cache (faster)
      },
    })

    if clear_cache then
      log.info('Full reindex (cache cleared)...', 'Intelephense')
    else
      log.info('Incremental reindex (using cache)...', 'Intelephense')
    end
  end, { bang = true, desc = 'Intelephense: Index workspace (use ! to clear cache)' })

  -- :IntelephenseCancelIndexing (matches VSCode "Cancel indexing")
  vim.api.nvim_create_user_command(CMD.CANCEL_INDEXING, function()
    local client = get_intelephense_client()
    if not client then
      return log.warn('Intelephense not running', 'Intelephense')
    end

    client:request('cancelIndexing', {}, function(err, _)
      if err then
        log.error('Failed to cancel: ' .. tostring(err), 'Intelephense')
      else
        log.info('Indexing cancelled', 'Intelephense')
      end
    end, 0)
  end, { desc = 'Intelephense: Cancel indexing' })
end

---Unregister Intelephense user commands
---@return nil
local function unregister_commands()
  pcall(vim.api.nvim_del_user_command, CMD.INDEX_WORKSPACE)
  pcall(vim.api.nvim_del_user_command, CMD.CANCEL_INDEXING)
end

intelephense.config = {
  init_options = {
    storagePath = STORAGE_PATH,
    -- globalStoragePath uses default ~/.intelephense (already cross-IDE)
    -- NOTE: clearCache is NOT set here (defaults to false for normal startup)
  },

  -- Register commands when LSP attaches
  on_attach = function(_, _)
    if commands_registered then
      return
    end
    commands_registered = true
    register_commands()
  end,

  -- Single client per session: always cleanup on exit (no race condition)
  on_exit = function(_, _, _)
    unregister_commands()
    commands_registered = false
  end,
}

M.lspconfigs = { intelephense }

---@type custom.DapConfig
local php_dap = {
  type = 'php',
  use_masondap_default_setup = true,
}
M.dapconfigs = { php_dap }

M.neotest_adapter_setup = function()
  local has_phpunit, phpunit = pcall(require, 'neotest-phpunit')
  return has_phpunit and phpunit or nil
end

return M
