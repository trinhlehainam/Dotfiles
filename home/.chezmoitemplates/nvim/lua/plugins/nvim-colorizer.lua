return {
  -- https://github.com/catgoose/nvim-colorizer.lua
  'catgoose/nvim-colorizer.lua',
  event = 'BufReadPre',
  -- https://github.com/catgoose/nvim-colorizer.lua?tab=readme-ov-file#default-configuration
  opts = {
    filetypes = {
      'css',
      'javascript',
      'typescript',
      html = { mode = 'foreground' },
    },
    display = {
      mode = 'background', -- "background"|"foreground"|"virtualtext"
    },
  },
}
