local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local obsidian = require('utils.obsidian')
local M = LanguageSetting:new()

M.treesitter.filetypes = { 'markdown', 'markdown_inline' }

---@param client vim.lsp.Client
local function restrict_marksman_to_hover_only(client)
  if not client.server_capabilities then
    return
  end

  client.handlers = client.handlers or {}

  local hover_provider = client.server_capabilities.hoverProvider
  client.server_capabilities = {}
  client.server_capabilities.hoverProvider = hover_provider
end

local marksman = LspConfig:new('marksman', 'marksman')
marksman.config = {
  on_attach = function(client, bufnr)
    if obsidian.is_vault(bufnr) then
      restrict_marksman_to_hover_only(client)
    end
  end,
}

M.lspconfigs = { marksman }

return M
