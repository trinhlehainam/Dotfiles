return {
  'mrjones2014/codesettings.nvim',
  lazy = false,
  config = function()
    require('codesettings').setup({
      live_reload = false,
      jsonls_integration = true,
      lua_ls_integration = true,
      extensions = {
        'codesettings.extensions.vscode',
      },
    })
  end,
}
