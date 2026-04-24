return {
  'XXiaoA/atone.nvim',
  cmd = 'Atone',
  ---@module "atone"
  ---@type AtoneConfig
  opts = {},
  keys = {
    { '<leader>u', '<cmd>Atone toggle<cr>', desc = 'Undo tree' },
  },
}
