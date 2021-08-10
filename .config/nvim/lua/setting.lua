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

w.wrap = false
w.cursorline = true
w.number = true
w.relativenumber = true

b.tabstop = 2
b.shiftwidth = 2
b.softtabstop = 2
b.expandtab = true
b.smartindent = true
b.autoindent = true
