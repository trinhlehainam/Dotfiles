local LanguageSetting = require('configs.lsp.base')
local M = LanguageSetting:new()

-- NOTE: mason-lspconfig hasn't supported for nginx-language-server yet
-- https://github.com/williamboman/mason-lspconfig.nvim/issues/298

local common = require('utils.common')

---@param nginx_lsp_pkg_path string
local function nginx_lsp_cmd(nginx_lsp_pkg_path)
  if common.IS_WINDOWS then
    return nginx_lsp_pkg_path .. '/venv/bin/nginx-language-server.exe'
  else
    return nginx_lsp_pkg_path .. '/venv/bin/nginx-language-server'
  end
end

M.after_masonlsp_setup = function()
  local mason_utils = require('utils.mason')
  local log = require('utils.log')

  if not mason_utils.has_mason() then
    log.error('Cannot load mason installer')
    return
  end

  -- NOTE: mason only install python3.9 execution, not actual nginx_language_server
  -- need to manually install with pip
  mason_utils.install({ 'nginx-language-server' })

  local nginx_lsp_path = mason_utils.get_mason_package_path('nginx-language-server')

  if not nginx_lsp_path then
    log.error('nginx-language-server is not installed in mason package')
    return
  end

  local on_attach = require('utils.lsp').on_attach
  local capabilities = require('utils.lsp').get_cmp_capabilities()
  -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#nginx_language_server
  require('lspconfig').nginx_language_server.setup({
    cmd = { nginx_lsp_cmd(nginx_lsp_path) },
    capabilities = capabilities,
    on_attach = on_attach,
  })
end

return M
