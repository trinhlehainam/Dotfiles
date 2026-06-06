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
local markdown_oxide_on_attach = assert(vim.lsp.config['markdown_oxide']).on_attach
markdown_oxide.config = {
  capabilities = capabilities,
  root_dir = function(bufnr, on_dir)
    if obsidian.is_vault(bufnr) then
      return
    end

    local path = vim.api.nvim_buf_get_name(bufnr)
    on_dir(vim.fs.root(path, { '.git', '.moxide.toml' }) or vim.fs.dirname(path) or vim.fn.getcwd())
  end,
  on_attach = function(client, bufnr)
    if obsidian.is_vault(bufnr) then
      vim.lsp.buf_detach_client(bufnr, client.id)
      return
    end

    if markdown_oxide_on_attach then
      markdown_oxide_on_attach(client, bufnr)
    end
  end,
}

M.lspconfigs = { markdown_oxide }

return M
