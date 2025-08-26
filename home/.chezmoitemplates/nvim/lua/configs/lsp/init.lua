--- @type custom.Lsp
local M = {
  treesitters = {},
  lspconfigs = {},
  dapconfigs = {},
  formatters = {},
  linters = {},
  after_masonlsp_setups = {},
  get_neotest_adapters = function()
    return {}
  end,
  plugin_setups = {},
}

local ignore_mods = { 'types', 'base', 'init', 'lspconfig' }

--- @type table<string, custom.LanguageSetting>
local language_settings = require('utils.common').load_mods('configs.lsp', ignore_mods)

---@type custom.NeotestAdapterSetup[]
local neotest_adapter_setups = {}

for lang, settings in pairs(language_settings) do
  table.insert(M.treesitters, settings.treesitter)
  M.dapconfigs[lang] = settings.dapconfig
  vim.list_extend(M.lspconfigs, settings.lspconfigs)
  table.insert(M.formatters, settings.formatterconfig)
  table.insert(M.linters, settings.linterconfig)
  table.insert(M.after_masonlsp_setups, settings.after_masonlsp_setup)
  if settings.neotest_adapter_setup then
    table.insert(neotest_adapter_setups, settings.neotest_adapter_setup)
  end
  if settings.plugin_setups then
    M.plugin_setups = vim.tbl_extend('error', M.plugin_setups, settings.plugin_setups)
  end
end

M.get_neotest_adapters = function()
  ---@type neotest.Adapter[]
  local neotest_adapters = {}

  for _, setup in ipairs(neotest_adapter_setups) do
    local adapter = setup()
    table.insert(neotest_adapters, adapter)
  end
  return neotest_adapters
end

return M
