return {
	"mg979/vim-visual-multi",
	config = function()
		-- NOTE: imap <BS> conflict with nvim-autopairs, so disable it
		-- INFO: https://github.com/mg979/vim-visual-multi/issues/243
		vim.g.VM_maps = {
			["I BS"] = "",
		}

		vim.g.VM_set_statusline = 0 -- disable VM's statusline updates to prevent clobbering
		vim.g.VM_silent_exit = 1 -- because the status line already tells me the mode
	end,
}
