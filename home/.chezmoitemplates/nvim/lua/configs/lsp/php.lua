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
  -- :IntelephenseIndexWorkspace (matches VSCode "Index workspace")
  -- Uses clearCache: true to clear ONLY current workspace cache
  vim.api.nvim_create_user_command(CMD.INDEX_WORKSPACE, function()
    local client = get_intelephense_client()
    if not client then
      return log.warn('Intelephense not running', 'Intelephense')
    end

    local root_dir = client.config.root_dir
    vim.lsp.stop_client(client.id)

    local function try_restart()
      if client:is_stopped() then
        vim.lsp.start({
          name = 'intelephense',
          cmd = { 'intelephense', '--stdio' },
          root_dir = root_dir,
          init_options = {
            storagePath = STORAGE_PATH,
            clearCache = true,
          },
        })
        log.info('Reindexing workspace...', 'Intelephense')
      else
        vim.defer_fn(try_restart, 50)
      end
    end

    try_restart()
  end, { desc = 'Intelephense: Index workspace' })

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
  on_exit = function(_code, _signal, _client_id)
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
