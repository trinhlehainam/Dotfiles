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

M.lspconfigs = { LspConfig:new('intelephense', 'intelephense') }

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
