local o = vim.o       -- global options
local w = vim.wo      -- window-local options
local b = vim.bo      -- buffer-local options

o.hidden = true
o.encoding = 'utf-8'
o.pumheight = 10
o.showmode = false
o.backup = false
o.ruler = true
o.mouse = 'a'
o.writebackup = false
o.splitbelow = true
o.splitright = true
o.smarttab = true
o.showtabline = 1
o.timeoutlen = 300
o.termguicolors = true
o.scrolloff = 8
-- o.clipboard = 'unnamedplus'
o.hlsearch = true
o.errorbells = false
o.ignorecase = true

w.wrap = false
w.cursorline = true
w.number = true
w.relativenumber = true
w.signcolumn = 'yes'
w.colorcolumn = '80'
w.foldmethod = 'marker'

-- b.tabstop = 2
-- b.shiftwidth = 2
-- b.softtabstop = 2
-- b.expandtab = true
-- b.smartindent = true
-- b.autoindent = true
b.swapfile = false
--b.undodir = '~/.config/nvim/undo'
b.undofile = true

-- NOTE: Indent setting in lua file doesn't work correctly -> use vim file
vim.cmd(
[[
set autoindent
set expandtab
set shiftwidth=4
set smartindent
set softtabstop=4
set tabstop=4
]]
)
