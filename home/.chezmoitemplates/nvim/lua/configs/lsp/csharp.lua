local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local M = LanguageSetting:new()

-- https://github.com/GustavEikaas/easy-dotnet.nvim?tab=readme-ov-file#requirements-5
M.treesitter.filetypes = { 'c_sharp', 'sql', 'json', 'xml' }

M.formatterconfig.servers = { 'csharpier' }
M.formatterconfig.formatters_by_ft = {
  cs = { 'csharpier' },
}

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

--- @source https://github.com/GustavEikaas/easy-dotnet.nvim/blob/main/docs/debugging.md
--- @type custom.DapConfig
local coreclr = {
  type = 'coreclr',
  use_masondap_default_setup = false,
}

-- https://github.com/GustavEikaas/easy-dotnet.nvim/blob/main/docs/debugging.md#configuration
coreclr.setup = function()
  local function rebuild_project(co, path)
    local spinner = require('easy-dotnet.ui-modules.spinner').new()
    spinner:start_spinner('Building')
    vim.fn.jobstart(string.format('dotnet build %s', path), {
      on_exit = function(_, return_code)
        if return_code == 0 then
          spinner:stop_spinner('Built successfully')
        else
          spinner:stop_spinner('Build failed with exit code ' .. return_code, vim.log.levels.ERROR)
          error('Build failed')
        end
        coroutine.resume(co)
      end,
    })
    coroutine.yield()
  end

  local dap = require('dap')

  -- .NET specific setup using `easy-dotnet`
  require('easy-dotnet.netcoredbg').register_dap_variables_viewer() -- special variables viewer specific for .NET
  local dotnet = require('easy-dotnet')
  local debug_dll = nil

  local function ensure_dll()
    if debug_dll ~= nil then
      return debug_dll
    end
    local dll = dotnet.get_debug_dll(true)
    debug_dll = dll
    return dll
  end

  for _, value in ipairs({ 'cs', 'fsharp' }) do
    dap.configurations[value] = {
      {
        type = 'coreclr',
        name = 'Program',
        request = 'launch',
        env = function()
          local dll = ensure_dll()
          local vars = dotnet.get_environment_variables(dll.project_name, dll.relative_project_path)
          return vars or nil
        end,
        program = function()
          local dll = ensure_dll()
          local co = coroutine.running()
          rebuild_project(co, dll.project_path)
          return dll.relative_dll_path
        end,
        cwd = function()
          local dll = ensure_dll()
          return dll.relative_project_path
        end,
      },
      {
        type = 'coreclr',
        name = 'Test',
        request = 'attach',
        processId = function()
          local res = require('easy-dotnet').experimental.start_debugging_test_project()
          return res.process_id
        end,
      },
    }
  end

  -- Reset debug_dll after each terminated session
  dap.listeners.before['event_terminated']['easy-dotnet'] = function()
    debug_dll = nil
  end

  dap.adapters.coreclr = {
    type = 'executable',
    command = 'netcoredbg',
    args = { '--interpreter=vscode' },
  }
end

M.dapconfigs = { coreclr }

return M
