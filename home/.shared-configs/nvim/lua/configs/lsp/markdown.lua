local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local obsidian = require('utils.obsidian')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'markdown', 'markdown_inline' }

local capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), {
  workspace = {
    didChangeWatchedFiles = {
      dynamicRegistration = true,
    },
  },
})

local ok, blink = pcall(require, 'blink.cmp')
if ok then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

local markdown_oxide = LspConfig:new('markdown_oxide', 'markdown-oxide')

-- NOTE: Keep this aligned with obsidian-ls capabilities that overlap with markdown-oxide:
-- https://github.com/obsidian-nvim/obsidian.nvim/blob/main/lua/obsidian/lsp/handlers/initialize.lua
-- https://github.com/obsidian-nvim/obsidian.nvim/wiki/LSP-Progress
local obsidian_lsp_capabilities = {
  'codeActionProvider',
  'completionProvider',
  'definitionProvider',
  'documentSymbolProvider',
  'referencesProvider',
  'renameProvider',
  'workspaceSymbolProvider',
}

markdown_oxide.config = {
  capabilities = capabilities,
  root_dir = function(bufnr, on_dir)
    local vault_root = obsidian.vault_root(bufnr)
    if vault_root then
      on_dir(vault_root)
      return
    end

    local path = vim.api.nvim_buf_get_name(bufnr)
    on_dir(vim.fs.root(path, { '.git', '.moxide.toml' }) or vim.fs.dirname(path) or vim.fn.getcwd())
  end,
  reuse_client = function(client, config)
    return client.name == config.name
      and vim.fs.normalize(client.config.root_dir or '')
        == vim.fs.normalize(config.root_dir or '')
  end,
  on_attach = function(client, bufnr)
    if not obsidian.is_vault(bufnr) then
      return
    end

    -- TODO: Remove this fallback when obsidian-ls covers the remaining markdown-oxide features.
    for _, capability in ipairs(obsidian_lsp_capabilities) do
      client.server_capabilities[capability] = nil
    end
  end,
}

M.lspconfigs = { markdown_oxide }

return M
