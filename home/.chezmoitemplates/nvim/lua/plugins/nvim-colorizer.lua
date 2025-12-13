return {
  -- https://github.com/catgoose/nvim-colorizer.lua
  'catgoose/nvim-colorizer.nvim',
  event = 'BufReadPre',
  opts = {
    filetypes = {
      'css',
      'javascript',
      'typescript',
      html = { mode = 'foreground' },
    },
    user_default_options = {
      mode = 'background',
    },
  },
}
