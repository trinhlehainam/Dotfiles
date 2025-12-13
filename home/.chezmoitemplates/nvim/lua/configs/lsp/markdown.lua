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

  client.server_capabilities.completionProvider = nil
  client.server_capabilities.definitionProvider = nil
  client.server_capabilities.declarationProvider = nil
  client.server_capabilities.implementationProvider = nil
  client.server_capabilities.typeDefinitionProvider = nil
  client.server_capabilities.referencesProvider = nil
  client.server_capabilities.documentFormattingProvider = nil
  client.server_capabilities.documentRangeFormattingProvider = nil
  client.server_capabilities.renameProvider = nil
  client.server_capabilities.codeActionProvider = nil
  client.server_capabilities.documentSymbolProvider = nil
  client.server_capabilities.workspaceSymbolProvider = nil
  client.server_capabilities.signatureHelpProvider = nil
  client.server_capabilities.documentHighlightProvider = nil
  client.server_capabilities.foldingRangeProvider = nil
  client.server_capabilities.selectionRangeProvider = nil
  client.server_capabilities.semanticTokensProvider = nil

  client.handlers['textDocument/publishDiagnostics'] = function() end
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
