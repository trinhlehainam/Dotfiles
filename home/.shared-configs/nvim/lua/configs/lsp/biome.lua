local filetypes = {
  'javascript',
  'javascriptreact',
  'jsonc',
  'typescript',
  'typescript.tsx',
  'typescriptreact',
}

---@type dotfiles.lsp.Language
return {
  filetypes = filetypes,
  tools = { 'biome' },
  server_tools = { biome = { 'biome' } },
  condition = function(bufnr)
    return require('utils.tool_root').find(bufnr, { 'biome.json', 'biome.jsonc' }, '@biomejs/biome')
      ~= nil
  end,
  servers = {
    biome = {
      -- JSON uses jq; retain Biome only for the existing diagnostic filetypes.
      filetypes = filetypes,
      -- Keep upstream's monorepo root and project-local binary selection.
    },
  },
}
