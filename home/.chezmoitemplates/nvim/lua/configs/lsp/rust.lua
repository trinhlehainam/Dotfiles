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

--- @type custom.DapConfig
local codelldb = {
  type = 'codelldb',
  use_masondap_default_setup = false,
}
M.dapconfigs = { codelldb }

M.neotest_adapter_setup = function()
  if not has_rustceanvim() then
    return nil
  end

  local has_neotest_rust, neotest_rust = pcall(require, 'rustaceanvim.neotest')
  if not has_neotest_rust then
    log.info('rustaceanvim.neotest is not installed')
    return nil
  end
  return neotest_rust
end

return M
