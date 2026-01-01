--- @type custom.Lsp
local M = {
  treesitters = {},
  lspconfigs = {},
  dapconfigs = {},
  formatters = {},
  linters = {},
  get_neotest_adapters = function()
    return {}
  end,
}

local ignore_mods = { 'types', 'base', 'init', 'lspconfig' }

--- @type table<string, custom.LanguageSetting>
local language_settings = require('utils.common').load_mods('configs.lsp', ignore_mods)

---@type custom.NeotestAdapterSetup[]
local neotest_adapter_setups = {}

for lang, settings in pairs(language_settings) do
  table.insert(M.treesitters, settings.treesitter)
  -- Collect all dapconfigs into a flat array
  if settings.dapconfigs and #settings.dapconfigs > 0 then
    vim.list_extend(M.dapconfigs, settings.dapconfigs)
  end
  vim.list_extend(M.lspconfigs, settings.lspconfigs)
  table.insert(M.formatters, settings.formatterconfig)
  table.insert(M.linters, settings.linterconfig)
  if settings.neotest_adapter_setup then
    table.insert(neotest_adapter_setups, settings.neotest_adapter_setup)
  end
end

M.get_neotest_adapters = function()
  ---@type neotest.Adapter[]
  local neotest_adapters = {}

  for _, setup in ipairs(neotest_adapter_setups) do
    local adapter = setup()
    if adapter then
      table.insert(neotest_adapters, adapter)
    end
  end
  return neotest_adapters
end

return M
