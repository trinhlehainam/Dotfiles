if vim.g.vscode then
  return
end

local dap = require('dap')
--- @type table<string, custom.Lang>
local langs = require('lsp').langs

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
  ensure_installed = dap_types,
}
