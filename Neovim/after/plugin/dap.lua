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
--- @type table<string, custom.LanguageSetting>
local language_settings = require('configs.lsp').language_settings

--- @type string[]
local daptypes = {}

for language, settings in pairs(language_settings) do
  local daptype = settings.daptype
  if daptype == nil or daptype == "" then goto continue end
  table.insert(daptypes, daptype)

  local dapconfig = settings.dapconfig
  if dapconfig == nil then goto continue end
  dap.configurations[language] = dapconfig

  ::continue::
end

require('mason-nvim-dap').setup {
  automatic_installation = true,
  ensure_installed = daptypes,
}
