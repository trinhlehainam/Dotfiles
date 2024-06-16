-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opts = {}
opts.nore = { noremap = true, silent = true }

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Copy to the end of line
vim.keymap.set("n", "Y", "yg_", opts.nore)

-- DELETE keys
vim.keymap.set("n", "s", "", opts.nore)
vim.keymap.set("n", "S", "", opts.nore)

-- Quick escape INSERT mode
vim.keymap.set("i", "jk", "<Esc>", opts.nore)

--Jump out of surround pairs
vim.keymap.set("i", "<C-e>", "<Esc>%%a", opts.nore)

--Window Navigation
vim.keymap.set("n", "<C-l>", "<C-w>l", opts.nore)
vim.keymap.set("n", "<C-k>", "<C-w>k", opts.nore)
vim.keymap.set("n", "<C-j>", "<C-w>j", opts.nore)
vim.keymap.set("n", "<C-h>", "<C-w>h", opts.nore)

-- These mappings control the size of splits (height/width)
vim.keymap.set("n", "<A-,>", "<c-w>5<", opts.nore)
vim.keymap.set("n", "<A-.>", "<c-w>5>", opts.nore)
vim.keymap.set("n", "<A-u>", "<C-W>+", opts.nore)
vim.keymap.set("n", "<A-d>", "<C-W>-", opts.nore)

--Buffer Navigation
vim.keymap.set("n", "bh", ":bfirst<CR>", opts.nore)
vim.keymap.set("n", "bl", ":blast<CR>", opts.nore)
vim.keymap.set("n", "bj", ":bprevious<CR>", opts.nore)
vim.keymap.set("n", "bk", ":bnext<CR>", opts.nore)
vim.keymap.set("n", "bc", ":bd<CR>", opts.nore)

--Move to begin/end word of line
vim.keymap.set("", "gl", "g_", opts.nore)
vim.keymap.set("", "gh", "^", opts.nore)

--Avoid break out nvim
vim.keymap.set("n", "<C-c>", "<Esc>", opts.nore)

--Paste without loss previous text
vim.keymap.set("x", "<leader>p", '"_dp', opts.nore)

--Copy,Paste in the system clipboard
--Use: checkhealth to check supported system clipboard
vim.keymap.set("n", "<C-y>", '"+y', opts.nore)
vim.keymap.set("v", "<C-y>", '"+y', opts.nore)
vim.keymap.set("n", "<C-p>", '"+p', opts.nore)
vim.keymap.set("i", "<C-p>", '<Esc>"+pa', opts.nore)

--Go to next/prev word in INSERT
vim.keymap.set("i", "<A-h>", "<Esc>i", opts.nore)
vim.keymap.set("i", "<A-l>", "<Esc>la", opts.nore)

--Keep cursor centered
vim.keymap.set("n", "n", "nzzzv", opts.nore)
vim.keymap.set("n", "N", "Nzzzv", opts.nore)
vim.keymap.set("n", "J", "mmJ`m", opts.nore)
vim.keymap.set("n", "gJ", "mmgJ`m", opts.nore)

-- NOTE: the following doesn't work for some reason
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts.nore)
vim.keymap.set("n", "<C-d>", "<C-d>zz", opts.nore)

--Undo break point
vim.keymap.set("i", ",", ",<C-g>u", opts.nore)
vim.keymap.set("i", ".", ".<C-g>u", opts.nore)
vim.keymap.set("i", "!", "!<C-g>u", opts.nore)
vim.keymap.set("i", "?", "?<C-g>u", opts.nore)
vim.keymap.set("i", ":", ":<C-g>u", opts.nore)
vim.keymap.set("i", ";", ";<C-g>u", opts.nore)
-- vim.keymap.set('i',' ',' <C-g>u',opts.nore)

--Undo in insert mode
vim.keymap.set("i", "<A-u>", "<Esc>ua", opts.nore)

--Moving line of text
vim.keymap.set("i", "<A-k>", "<Esc>:m.-2<CR>==a", opts.nore)
vim.keymap.set("i", "<A-j>", "<Esc>:m.+1<CR>==a", opts.nore)
vim.keymap.set("n", "<A-k>", ":m.-2<CR>==", opts.nore)
vim.keymap.set("n", "<A-j>", ":m.+1<CR>==", opts.nore)
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", opts.nore)
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", opts.nore)

--Re-visual after indent
vim.keymap.set("v", ">", ">gv=gv", opts.nore)
vim.keymap.set("v", "<", "<gv=gv", opts.nore)
