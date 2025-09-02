local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'rust', 'toml' }

local log = require('utils.log')

local function has_rustceanvim()
  local hasrustaceanvim, _ = pcall(require, 'rustaceanvim')
  if not hasrustaceanvim then
    log.error('rustaceanvim is not installed')
    return false
  end
  return true
end

-- Rustaceanvim will setup LSP and DAP
-- https://github.com/mrcjkb/rustaceanvim?tab=readme-ov-file#zap-quick-setup
M.lspconfigs = { LspConfig:new(nil, 'rust-analyzer') }

M.dapconfig.type = 'codelldb'
M.dapconfig.use_masondap_default_setup = false

M.neotest_adapter_setup = function()
  if not has_rustceanvim() then
    return {}
  end

  local has_neotest_rust, neotest_rust = pcall(require, 'rustaceanvim.neotest')
  if not has_neotest_rust then
    log.info('rustaceanvim.neotest is not installed')
    return {}
  end
  return neotest_rust
end

return M
