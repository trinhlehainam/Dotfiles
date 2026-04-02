local M = {}

---@return dotfiles.lsp.LanguageSetting
function M:new()
  ---@type dotfiles.lsp.LanguageSetting
  local t = setmetatable({}, { __index = M })
  t.treesitter = {
    filetypes = nil,
  }
  t.lspconfigs = {}
  t.dapconfigs = {}
  t.formatterconfig = {
    mason_packages = nil,
    formatters_by_ft = nil,
  }
  t.linterconfig = {
    mason_packages = nil,
    linters_by_ft = nil,
    lint_on_save = true,
  }
  t.neotest_adapter_setup = nil
  return t
end

return M
