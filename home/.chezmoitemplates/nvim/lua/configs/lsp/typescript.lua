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

M.formatterconfig.servers = { 'prettierd' }
M.formatterconfig.formatters_by_ft = {
  javascriptreact = { 'rustywind' },
  typescriptreact = { 'rustywind' },
  vue = { 'rustywind', 'prettierd' },
}

M.linterconfig.servers = { 'eslint_d', 'markuplint' }
M.linterconfig.linters_by_ft = {
  javascriptreact = { 'markuplint' },
  typescriptreact = { 'markuplint' },
  vue = { 'eslint_d', 'markuplint' },
}

local volar = LspConfig:new('volar')
volar.use_masonlsp_setup = false

local vtsls = LspConfig:new('vtsls')
vtsls.setup = function(capabilities, on_attach)
  local log = require('utils.log')

  local hasmason, registry = pcall(require, 'mason-registry')
  local haslspconfig, lspconfig = pcall(require, 'lspconfig')

  if not hasmason then
    log.error('mason.nvim is not installed')
    return
  end

  if not haslspconfig then
    log.error('lspconfig is not installed')
    return
  end

  local volar_pkg = registry.get_package('vue-language-server')
  if not volar_pkg:is_installed() then
    log.error('vue-language-server is not installed')
    return
  end

  -- INFO:
  --	- https://github.com/vuejs/language-tools?tab=readme-ov-file#community-integration
  --	- https://vuejs.org/guide/typescript/overview.html#volar-takeover-mode
  --	- https://github.com/mason-org/mason-registry/issues/5064
  --	- https://stackoverflow.com/a/59788563
  local vue_language_server_path = volar_pkg:get_install_path()
    .. '/node_modules/@vue/language-server'

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

  lspconfig.vtsls.setup({
    filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
    capabilities = capabilities,
    on_attach = on_attach,
    settings = {
      -- Inlay hints config
      -- INFO: https://github.com/yioneko/nvim-vtsls?tab=readme-ov-file#other-useful-snippets
      typescript = configuration,
      javascript = configuration,
      vtsls = {
        tsserver = {
          globalPlugins = {
            {
              name = '@vue/typescript-plugin',
              location = vue_language_server_path,
              languages = { 'vue' },
              configNamespace = 'typescript',
              enableForWorkspaceTypeScriptVersions = true,
            },
          },
        },
      },
    },
  })
end

-- Formatter and Linter server
local biome = LspConfig:new('biome')
biome.setup = function(_, _)
  -- TODO:
  require('lspconfig').biome.setup({
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
  })
end

M.lspconfigs = { volar, vtsls, biome }

return M
