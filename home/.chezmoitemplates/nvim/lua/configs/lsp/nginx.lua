local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
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

local log = require('utils.log')
local mason_utils = require('utils.mason')
local nginx_lsp_path = mason_utils.get_mason_package_path('nginx-language-server')
if not nginx_lsp_path then
  log.info('nginx-language-server is not installed in mason package')
  return M
end

local nginx_lsp = LspConfig:new('nginx_language_server', 'nginx-language-server')
nginx_lsp.config = {
  cmd = { nginx_lsp_cmd(nginx_lsp_path) },
}

M.lspconfigs = { nginx_lsp }

return M
