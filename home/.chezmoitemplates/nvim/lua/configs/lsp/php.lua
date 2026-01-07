local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
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

-- Cross-IDE cache path (no /nvim/ prefix for sharing with Emacs, Helix, etc.)
local cache_dir = vim.fn.expand('~/.cache/intelephense')

-- Local state management (no vim.g pollution)
local commands_registered = false

-- Helper to get intelephense clients
local function get_clients()
  return vim.lsp.get_clients({ name = 'intelephense' })
end

-- Command implementations
local function create_commands()
  -- :IntelephenseIndexWorkspace (matches VSCode "Index workspace")
  -- Uses clearCache: true to clear ONLY current workspace cache
  vim.api.nvim_create_user_command('IntelephenseIndexWorkspace', function()
    local clients = get_clients()
    if #clients == 0 then
      return vim.notify('Intelephense not running', vim.log.levels.WARN)
    end

    -- Get root_dir from existing client
    local root_dir = clients[1].config.root_dir

    -- Stop all intelephense clients
    for _, client in ipairs(clients) do
      vim.lsp.stop_client(client.id)
    end

    -- Restart with clearCache: true (clears only THIS workspace)
    vim.defer_fn(function()
      vim.lsp.start({
        name = 'intelephense',
        cmd = { 'intelephense', '--stdio' },
        root_dir = root_dir,
        init_options = {
          storagePath = cache_dir,
          globalStoragePath = cache_dir,
          clearCache = true, -- KEY: Clears only current workspace cache!
        },
      })
      vim.notify('Reindexing workspace...', vim.log.levels.INFO)
    end, 100)
  end, { desc = 'Intelephense: Index workspace' })

  -- :IntelephenseCancelIndexing (matches VSCode "Cancel indexing")
  -- Sends cancelIndexing LSP request to server
  vim.api.nvim_create_user_command('IntelephenseCancelIndexing', function()
    local clients = get_clients()
    if #clients == 0 then
      return vim.notify('Intelephense not running', vim.log.levels.WARN)
    end

    for _, client in ipairs(clients) do
      client:request('cancelIndexing', {}, function(err, _)
        if err then
          vim.notify('Failed to cancel: ' .. tostring(err), vim.log.levels.ERROR)
        else
          vim.notify('Indexing cancelled', vim.log.levels.INFO)
        end
      end, 0)
    end
  end, { desc = 'Intelephense: Cancel indexing' })
end

local function delete_commands()
  pcall(vim.api.nvim_del_user_command, 'IntelephenseIndexWorkspace')
  pcall(vim.api.nvim_del_user_command, 'IntelephenseCancelIndexing')
end

intelephense.config = {
  init_options = {
    storagePath = cache_dir,
    globalStoragePath = cache_dir,
    -- Note: clearCache is NOT set here (defaults to false for normal startup)
  },

  -- Register commands when LSP attaches
  on_attach = function(_, _)
    if commands_registered then
      return
    end
    commands_registered = true
    create_commands()
  end,

  -- Cleanup commands when LSP server process terminates (Neovim 0.11+)
  -- This is simpler than LspDetach autocmd - no delays or tracking needed
  on_exit = function(_, _, client_id)
    -- Check if any OTHER intelephense clients remain
    local remaining = vim.tbl_filter(function(c)
      return c.id ~= client_id
    end, get_clients())

    if #remaining == 0 then
      delete_commands()
      commands_registered = false
    end
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
