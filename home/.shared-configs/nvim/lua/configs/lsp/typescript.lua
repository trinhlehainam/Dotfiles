local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

M.treesitter.filetypes = {
  'javascript',
  'tsx',
  'typescript',
  'html',
  'css',
}

M.formatterconfig.mason_packages = { 'prettierd' }
M.formatterconfig.formatters_by_ft = {
  javascriptreact = { 'rustywind' },
  typescriptreact = { 'rustywind' },
  vue = { 'rustywind', 'prettierd' },
}

M.linterconfig.mason_packages = { 'eslint_d', 'markuplint' }
M.linterconfig.linters_by_ft = {
  javascriptreact = { 'markuplint' },
  typescriptreact = { 'markuplint' },
  vue = { 'eslint_d', 'markuplint' },
}

local vue_ls = LspConfig:new('vue_ls', 'vue-language-server')

local vtsls = LspConfig:new('vtsls', 'vtsls')

-- vtsls configuration scheme
-- INFO: https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json
local configuration = {
  inlayHints = {
    parameterNames = { enabled = 'literals' },
    parameterTypes = { enabled = true },
    variableTypes = { enabled = true },
    propertyDeclarationTypes = { enabled = true },
    functionLikeReturnTypes = { enabled = true },
    enumMemberValues = { enabled = true },
  },
  -- NOTE: use Biome for formatting
  format = { enable = false },
}

vtsls.config = {
  filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
  settings = {
    -- Inlay hints config
    -- INFO: https://github.com/yioneko/nvim-vtsls?tab=readme-ov-file#other-useful-snippets
    typescript = configuration,
    javascript = configuration,
  },
}

-- Formatter and Linter server
local biome = LspConfig:new('biome', 'biome')
biome.config = {
  -- TODO:
  filetypes = {
    'javascript',
    'javascriptreact',
    -- NOTE: use jq for formatting
    -- "json",
    'jsonc',
    'typescript',
    'typescript.tsx',
    'typescriptreact',
    -- NOTE: Below languages are not completely supported
    -- INFO: https://biomejs.dev/internals/language-support/
    -- "astro",
    -- "svelte",
    -- "vue",
    -- "css",
  },
}

M.lspconfigs = { vue_ls, vtsls, biome }

return M
