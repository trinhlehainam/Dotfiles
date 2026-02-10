return {
  'rachartier/tiny-inline-diagnostic.nvim',
  event = 'VeryLazy',
  priority = 1000,
  config = function()
    -- https://github.com/rachartier/tiny-inline-diagnostic.nvim?tab=readme-ov-file#configuration
    require('tiny-inline-diagnostic').setup()
  end,
}
