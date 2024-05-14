if vim.g.vscode then
  return
end

vim.api.nvim_set_hl(0, 'DapBreakpoint', { ctermbg = 0, fg = '#993939', bg = '#31353f' })
vim.api.nvim_set_hl(0, 'DapLogPoint', { ctermbg = 0, fg = '#61afef', bg = '#31353f' })
vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 0, fg = '#98c379', bg = '#31353f' })

vim.fn.sign_define('DapBreakpoint',
  { text = '🔴', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' })
vim.fn.sign_define('DapBreakpointCondition',
  { text = '🔴', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' })
vim.fn.sign_define('DapBreakpointRejected',
  { text = '', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' })
vim.fn.sign_define('DapLogPoint', { text = '', texthl = 'DapLogPoint', linehl = 'DapLogPoint', numhl = 'DapLogPoint' })
vim.fn.sign_define('DapStopped', { text = '', texthl = 'DapStopped', linehl = 'DapStopped', numhl = 'DapStopped' })

local dap = require('dap')
--- @type table<string, custom.Lang>
local langs = require('configs.lsp').langs

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
