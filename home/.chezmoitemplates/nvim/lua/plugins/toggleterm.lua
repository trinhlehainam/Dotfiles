return {
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		config = function()
			-- Change default shell to powershell on Windows
			-- Ref: https://github.com/akinsho/toggleterm.nvim/wiki/Tips-and-Tricks#using-toggleterm-with-powershell
			if vim.fn.has("win32") == 1 then
				local powershell_options = {
					shell = vim.fn.executable("pwsh") == 1 and "pwsh" or "powershell",
					shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;",
					shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait",
					shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode",
					shellquote = "",
					shellxquote = "",
				}

				for option, value in pairs(powershell_options) do
					vim.opt[option] = value
				end
			end

			require("toggleterm").setup()

			vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm<cr>", { desc = "[T]oggle [T]erminal" })
			function _G.set_terminal_keymaps()
				local opts = { buffer = 0, silent = true }
				vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
				vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
				vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
			end

			-- if you only want these mappings for toggle term use term://*toggleterm#* instead
			vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
		end,
	},
}
