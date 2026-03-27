local M = {}

-- https://github.com/nvim-lua/kickstart.nvim
--
-- Install package manager
--    https://github.com/folke/lazy.nvim
--    `:help lazy.nvim.txt` for more info

local function ensure_lazy_installed()
  local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
      'git',
      'clone',
      '--filter=blob:none',
      'https://github.com/folke/lazy.nvim.git',
      '--branch=stable', -- latest stable release
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
end

---@return LazySpec
function M.default_specs()
  return {
    -- NOTE: First, some plugins that don't require any configuration

    -- Detect tabstop and shiftwidth automatically
    'NMAC427/guess-indent.nvim',

    -- NOTE: The import below automatically adds your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
    --    You can use this folder to prevent any conflicts with this init.lua if you're interested in keeping
    --    up-to-date with whatever is in the kickstart repo.
    --
    --    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
    --    # https://github.com/vscode-neovim/vscode-neovim/wiki/Plugins#lazy-plugin-management
    {
      import = 'plugins',
      cond = function()
        return not vim.g.vscode
      end,
    },
  }
end

---@param opts? { specs?: LazySpec, config?: LazyConfig }
function M.setup(opts)
  opts = opts or {}

  ensure_lazy_installed()
  require('lazy').setup(vim.deepcopy(opts.specs or M.default_specs()), opts.config or {})
end

return M
