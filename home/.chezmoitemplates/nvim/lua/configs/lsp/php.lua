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

---@type string XDG-compliant project cache path (globalStoragePath uses default ~/.intelephense)
local STORAGE_PATH = vim.fn.expand('~/.cache/intelephense')

---@enum IntelephenseCommand
local CMD = {
  INDEX_WORKSPACE = 'IntelephenseIndexWorkspace',
  CANCEL_INDEXING = 'IntelephenseCancelIndexing',
}

---@type boolean Local state management (no vim.g pollution)
local commands_registered = false

---Get all active Intelephense LSP clients
---@return vim.lsp.Client[]
local function get_clients()
  return vim.lsp.get_clients({ name = 'intelephense' })
end

---Register Intelephense user commands
---@return nil
local function register_commands()
  -- :IntelephenseIndexWorkspace (matches VSCode "Index workspace")
  -- Uses clearCache: true to clear ONLY current workspace cache
  vim.api.nvim_create_user_command(CMD.INDEX_WORKSPACE, function()
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

    -- Wait for clients to stop, then restart with clearCache: true
    local function try_restart()
      -- Check if all clients have stopped
      local all_stopped = true
      for _, client in ipairs(clients) do
        if not client:is_stopped() then
          all_stopped = false
          break
        end
      end

      if all_stopped then
        vim.lsp.start({
          name = 'intelephense',
          cmd = { 'intelephense', '--stdio' },
          root_dir = root_dir,
          init_options = {
            storagePath = STORAGE_PATH,
            -- globalStoragePath uses default ~/.intelephense (already cross-IDE)
            clearCache = true, -- KEY: Clears only current workspace cache!
          },
        })
        vim.notify('Reindexing workspace...', vim.log.levels.INFO)
      else
        vim.defer_fn(try_restart, 50)
      end
    end

    try_restart()
  end, { desc = 'Intelephense: Index workspace' })

  -- :IntelephenseCancelIndexing (matches VSCode "Cancel indexing")
  -- Sends cancelIndexing LSP request to server
  vim.api.nvim_create_user_command(CMD.CANCEL_INDEXING, function()
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

  -- Cleanup commands when LSP server process terminates (Neovim 0.11+)
  -- This is simpler than LspDetach autocmd - no delays or tracking needed
  ---@param _ integer exit code
  ---@param _ integer signal
  ---@param client_id integer client ID
  on_exit = function(_, _, client_id)
    -- Check if any OTHER intelephense clients remain
    local remaining = vim.tbl_filter(function(c)
      return c.id ~= client_id
    end, get_clients())

    if #remaining == 0 then
      unregister_commands()
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
