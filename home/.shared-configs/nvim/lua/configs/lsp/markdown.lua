local obsidian = require('utils.obsidian')

-- Disable overlapping features in vaults; obsidian-ls supplies them there.
-- Keep aligned with obsidian.nvim/lua/obsidian/lsp/handlers/initialize.lua.
local obsidian_lsp_capabilities = {
  'codeActionProvider',
  'completionProvider',
  'definitionProvider',
  'documentSymbolProvider',
  'referencesProvider',
  'renameProvider',
  'workspaceSymbolProvider',
}

---@type dotfiles.lsp.Language
return {
  parsers = { 'markdown', 'markdown_inline' },
  tools = { 'markdown-oxide' },
  servers = {
    markdown_oxide = {
      capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } },
      root_dir = function(bufnr, on_dir)
        local vault_root = obsidian.vault_root(bufnr)
        if vault_root then
          on_dir(vault_root)
          return
        end

        local path = vim.api.nvim_buf_get_name(bufnr)
        on_dir(
          vim.fs.root(path, { '.git', '.moxide.toml' }) or vim.fs.dirname(path) or vim.fn.getcwd()
        )
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
    },
  },
}
