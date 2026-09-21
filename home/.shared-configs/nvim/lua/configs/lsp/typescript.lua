local configuration = {
  inlayHints = {
    parameterNames = { enabled = 'literals' },
    parameterTypes = { enabled = true },
    variableTypes = { enabled = true },
    propertyDeclarationTypes = { enabled = true },
    functionLikeReturnTypes = { enabled = true },
    enumMemberValues = { enabled = true },
  },
  -- Conform owns formatting so it also works outside Biome projects.
  format = { enable = false },
}

---@type dotfiles.lsp.Language
return {
  parsers = { 'javascript', 'tsx', 'typescript', 'html', 'css', 'vue' },
  tools = { 'vue-language-server', 'vtsls', 'biome', 'prettierd', 'eslint_d', 'markuplint' },
  servers = {
    vue_ls = {},
    vtsls = {
      filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
      settings = {
        vtsls = {
          tsserver = {
            globalPlugins = {
              {
                name = '@vue/typescript-plugin',
                location = vim.fs.joinpath(
                  vim.fn.stdpath('data'),
                  'mason/packages/vue-language-server/node_modules/@vue/language-server'
                ),
                languages = { 'vue' },
                configNamespace = 'typescript',
              },
            },
          },
        },
        -- Inlay hints config
        -- INFO: https://github.com/yioneko/nvim-vtsls?tab=readme-ov-file#other-useful-snippets
        typescript = configuration,
        javascript = configuration,
      },
    },
    biome = {
      -- JSON uses jq; keep Biome diagnostics for JavaScript and TypeScript.
      filetypes = {
        'javascript',
        'javascriptreact',
        'jsonc',
        'typescript',
        'typescript.tsx',
        'typescriptreact',
      },
    },
  },
  formatters = {
    javascript = { 'prettierd' },
    typescript = { 'prettierd' },
    javascriptreact = { 'rustywind', 'prettierd' },
    typescriptreact = { 'rustywind', 'prettierd' },
    vue = { 'rustywind', 'prettierd' },
  },
  linters = {
    javascriptreact = { 'markuplint' },
    typescriptreact = { 'markuplint' },
    vue = { 'eslint_d', 'markuplint' },
  },
}
