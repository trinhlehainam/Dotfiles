local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

local log = require('utils.log')
local common = require('utils.common')

if common.IS_WINDOWS then
  log.info('php language server is not supported on Windows')
  return M
end

M.treesitter.filetypes = { 'php' }

M.formatterconfig.servers = { 'blade-formatter', 'pint' }
M.formatterconfig.formatters_by_ft = {
  blade = { 'blade-formatter' },
  php = { 'pint' },
}

-- M.linterconfig.servers = { 'phpcs' }
-- M.linterconfig.linters_by_ft = {
--   php = { 'phpcs' },
-- }

M.lspconfigs = { LspConfig:new('phpactor', 'phpactor') }

--- @type custom.DapConfig
local php_dap = {
  type = 'php',
  use_masondap_default_setup = true,
}
M.dapconfigs = { php_dap }

M.neotest_adapter_setup = function()
  local has_phpunit, phpunit = pcall(require, 'neotest-phpunit')
  if not has_phpunit then
    return {}
  end
  return phpunit
end

return M
