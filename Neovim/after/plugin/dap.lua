local dap = require('dap')

require('mason-nvim-dap').setup {
  automatic_installation = true,
  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = {
    -- Update this to ensure that you have the debuggers for the langs you want
    'codelldb',
  },
}

for _, lang in pairs(require('lsp')) do
  dap.configurations[lang.lang] = lang.dapconfig
end
