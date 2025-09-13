local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

-- https://github.com/GustavEikaas/easy-dotnet.nvim?tab=readme-ov-file#requirements-5
M.treesitter.filetypes = { 'c_sharp', 'sql', 'json', 'xml' }

local roslyn = LspConfig:new('roslyn', 'roslyn')
-- https://github.com/GustavEikaas/nvim-config/blob/main/lua/plugins/roslyn.lua
roslyn.config = {
  settings = {
    ['csharp|background_analysis'] = {
      dotnet_compiler_diagnostics_scope = 'fullSolution',
    },
    ['csharp|inlay_hints'] = {
      csharp_enable_inlay_hints_for_implicit_object_creation = true,
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
      csharp_enable_inlay_hints_for_lambda_parameter_types = true,
      csharp_enable_inlay_hints_for_types = true,
      dotnet_enable_inlay_hints_for_indexer_parameters = true,
      dotnet_enable_inlay_hints_for_literal_parameters = true,
      dotnet_enable_inlay_hints_for_object_creation_parameters = true,
      dotnet_enable_inlay_hints_for_other_parameters = true,
      dotnet_enable_inlay_hints_for_parameters = true,
      dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
    },
    ['csharp|code_lens'] = {
      dotnet_enable_references_code_lens = true,
    },
  },
}
M.lspconfigs = { roslyn }

-- https://github.com/GustavEikaas/easy-dotnet.nvim/blob/main/docs/debugging.md
-- TODO: Add DAP config

return M
