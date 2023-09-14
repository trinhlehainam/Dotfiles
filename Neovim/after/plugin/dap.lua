local dap = require('dap')
local langs = require('lsp')

local dap_types = {}
for lang_name, lang_config in pairs(langs) do
  if lang_config.dap_type then
    dap_types[lang_config.dap_type] = {}
  end

  if lang_config.dapconfig then
    dap.configurations[lang_name] = lang_config.dapconfig
  end
end

require('mason-nvim-dap').setup {
  automatic_installation = true,
  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = vim.tbl_keys(dap_types),
}
