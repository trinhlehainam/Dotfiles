local dap = require('dap')
local langs = require('lsp')

local dap_types = {}
for lang_name, lang_config in pairs(langs) do
  dap_types[lang_config.dap_type] = {}
  dap.configurations[lang_name] = lang_config.dapconfig
end

require('mason-nvim-dap').setup {
  automatic_installation = true,
  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = vim.tbl_keys(dap_types),
}
