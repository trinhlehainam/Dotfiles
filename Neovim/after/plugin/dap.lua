local dap = require('dap')
--- @type table<string, lang>
local langs = require('lsp')

--- @type string[]
local dap_types = {}

for lang_name, lang_config in pairs(langs) do
  local dap_type = lang_config.dap_type
  if not dap_type then goto continue end
  table.insert(dap_types, dap_type)

  local dapconfig = lang_config.dapconfig
  if not dapconfig then goto continue end
  dap.configurations[lang_name] = dapconfig

  ::continue::
end

require('mason-nvim-dap').setup {
  automatic_installation = true,
  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = dap_types,
}
