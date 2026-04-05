return {
  'mrjones2014/codesettings.nvim',
  lazy = false,
  opts = function()
    return {
      config_file_paths = { '.vscode/settings.json' },
      live_reload = false,
      jsonls_integration = true,
      lua_ls_integration = true,
      root_dir = function()
        return require('configs.project.json').find_root(0)
      end,
    }
  end,
}
