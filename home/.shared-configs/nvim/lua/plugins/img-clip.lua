local function is_obsidian_vault()
  local ok, obsidian = pcall(require, 'utils.obsidian')
  if not ok then
    return false
  end

  return obsidian.is_vault(0)
end

return {
  -- https://github.com/HakonHarnes/img-clip.nvim
  'HakonHarnes/img-clip.nvim',
  event = 'VeryLazy',
  -- https://github.com/HakonHarnes/img-clip.nvim
  opts = {
    default = {
      dir_path = function()
        return (is_obsidian_vault() and 'Files') or 'assets'
      end,
      file_name = function()
        return (is_obsidian_vault() and 'Pasted image %Y%m%d%H%M%S') or '%Y-%m-%d-%H-%M-%S'
      end,
    },
  },
  keys = {
    -- suggested keymap
    { '<leader>p', '<cmd>PasteImage<cr>', desc = 'Paste image from system clipboard' },
  },
}
