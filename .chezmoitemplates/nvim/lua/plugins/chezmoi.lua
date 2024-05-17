return {
	'xvzc/chezmoi.nvim',
	dependencies = {
		'nvim-lua/plenary.nvim',
		'nvim-telescope/telescope.nvim'
	},
	config = function()
		require("chezmoi").setup {
			-- your configurations
		}
	end
}
