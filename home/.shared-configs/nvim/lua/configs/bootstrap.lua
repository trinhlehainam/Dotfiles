local M = {}

---@param opts? { lazy?: { specs?: LazySpec, config?: LazyConfig } }
function M.setup(opts)
  opts = opts or {}

  require('configs.options')
  require('configs.keymaps')

  -- Opt in per editor invocation: nvim --cmd 'let[g:dotfiles_minimal]=[v:true]'.
  -- List assignment avoids spaces: some agent editors split EDITOR without shell quoting.
  -- Prompt edits need neither plugin installation nor project/session side effects.
  if vim.g.dotfiles_minimal then
    vim.o.showmode = true
    return
  end

  require('configs.lazy').setup(opts.lazy)
  require('configs.project').setup()

  if vim.g.vscode then
    require('configs.vscode')
  end
  -- The line beneath this is called `modeline`. See `:help modeline`
  -- vim: ts=2 sts=2 sw=2 et
end

return M
