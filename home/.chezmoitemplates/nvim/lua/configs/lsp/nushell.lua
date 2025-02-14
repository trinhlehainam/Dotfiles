local LanguageSetting = require('configs.lsp.base')
local M = LanguageSetting:new()

-- NOTE: https://github.com/nushell/nu_scripts

M.treesitter.filetypes = { 'nu' }

M.after_masonlsp_setup = function()
  -- Check nu command is excutable
  if vim.fn.executable('nu') == 0 then
    require('utils.log').info('Nushell is not installed')
    return
  end

  local on_attach = require('utils.lsp').on_attach
  local capabilities = require('utils.lsp').get_cmp_capabilities()
  require('lspconfig').nushell.setup({
    capabilities = capabilities,
    on_attach = on_attach,
  })
end

return M
