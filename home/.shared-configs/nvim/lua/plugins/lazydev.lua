return {
  -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
  -- used for completion, annotations and signatures of Neovim apis
  'folke/lazydev.nvim',
  ft = 'lua',
  dependencies = {
    {
      -- https://github.com/DrKJeff16/wezterm-types?tab=readme-ov-file#installation
      'DrKJeff16/wezterm-types',
      lazy = true,
      version = false, -- Get the latest version
    },
  },
  opts = {
    library = {
      -- Load luvit types when the `vim.uv` word is found
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      { path = 'wezterm-types', mods = { 'wezterm' } },
    },
  },
}
