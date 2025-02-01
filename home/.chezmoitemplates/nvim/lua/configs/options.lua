-- [[ Setting options ]]
-- See `:help vim.o`

-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = "a"

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = "unnamedplus"

if vim.fn.has("wsl") == 1 then
	if vim.fn.executable("wl-copy") == 0 then
		print("wl-clipboard not found, clipboard integration won't work")
	else
		vim.g.clipboard = {
			name = "wl-clipboard (wsl)",
			copy = {
				["+"] = "wl-copy --foreground --type text/plain",
				["*"] = "wl-copy --foreground --primary --type text/plain",
			},
			paste = {
				["+"] = function()
					return vim.fn.systemlist('wl-paste --no-newline|sed -e "s/\r$//"', { "" }, 1) -- '1' keeps empty lines
				end,
				["*"] = function()
					return vim.fn.systemlist('wl-paste --primary --no-newline|sed -e "s/\r$//"', { "" }, 1)
				end,
			},
			cache_enabled = true,
		}
	end
end

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- [[ Custom settings

-- Disable break line when text go off editor's window
vim.o.wrap = false

-- Indicate limit number of character in oneline shouldn't be crossed
vim.o.colorcolumn = "80"

vim.o.relativenumber = true

if not vim.g.vscode then
	vim.opt.spelllang = "en_us"
	vim.opt.spell = true
end

-- Tabstop settings
vim.cmd([[
set tabstop=4
set shiftwidth=4
set softtabstop=4
set noexpandtab
set smartindent
set smarttab
]])

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

local utils = require("utils.common")
-- https://github.com/williamboman/mason.nvim/issues/1753
if utils.IS_WINDOWS and vim.fn.executable("pyenv") then
	local version = vim.fn.system("pyenv global"):gsub("\n", "")
	local user_profile = vim.fn.getenv("USERPROFILE")
	local python_path = user_profile .. "/.pyenv/pyenv-win/versions/" .. version
	if vim.fn.isdirectory(python_path) then
		local path = vim.fn.getenv("PATH")
		vim.fn.setenv("PATH", python_path .. ";" .. path)
	end
end
