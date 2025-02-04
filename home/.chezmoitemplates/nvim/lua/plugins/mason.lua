-- NOTE: Mason only registers packages to mason-registry when require("mason").setup is called
-- Make sure to setup mason before other plugins that use the mason-registry

return {
  'williamboman/mason.nvim',
  config = function()
    -- Setup mason so it can manage external tooling
    require('mason').setup({
      inlay_hints = { enalbed = true },
    })
  end,
}
