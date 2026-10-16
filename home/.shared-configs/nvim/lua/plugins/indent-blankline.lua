return {
  'lukas-reineke/indent-blankline.nvim',
  main = 'ibl',
  ---@module "ibl"
  ---@type ibl.config
  opts = {
    exclude = { filetypes = { 'bigfile' } },
    indent = {
      char = '╎',
    },
  },
}
