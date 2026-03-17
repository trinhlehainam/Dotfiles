local M = {}

---@param opts? { lazy?: { specs?: LazySpec, config?: LazyConfig } }
function M.setup(opts)
  opts = opts or {}

  require('configs.options')
  require('configs.keymaps')
  require('configs.lazy').setup(opts.lazy)
  require('configs.project')

  if vim.g.vscode then
    require('configs.vscode')
  end
  -- The line beneath this is called `modeline`. See `:help modeline`
  -- vim: ts=2 sts=2 sw=2 et
end

return M
