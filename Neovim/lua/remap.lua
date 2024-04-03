-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local opts = {}
opts.nore = { noremap = true, silent = true }

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'l', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'k', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Copy to the end of line
vim.keymap.set('n', 'Y', 'yg_', opts.nore)

-- DELETE keys
vim.keymap.set('n', 's', '', opts.nore)
vim.keymap.set('n', 'S', '', opts.nore)

-- Quick escape INSERT mode
vim.keymap.set('i', 'jk', '<Esc>', opts.nore)

--Jump out of surround pairs
vim.keymap.set('i', '<C-e>', '<Esc>%%a', opts.nore)

--Change hjkl -> jkl;
vim.keymap.set('', ';', 'l', opts.nore)
vim.keymap.set('', 'l', 'k', opts.nore)
vim.keymap.set('', 'k', 'j', opts.nore)
vim.keymap.set('', 'j', 'h', opts.nore)

--Window Navigation
vim.keymap.set('n', '<leader>;', '<C-w>l', opts.nore)
vim.keymap.set('n', '<leader>l', '<C-w>k', opts.nore)
vim.keymap.set('n', '<leader>k', '<C-w>j', opts.nore)
vim.keymap.set('n', '<leader>j', '<C-w>h', opts.nore)
vim.keymap.set('n', '<leader>c', '<C-w>c', opts.nore)

--Buffer Navigation
vim.keymap.set('n', 'bj', ':bfirst<CR>', opts.nore)
vim.keymap.set('n', 'b;', ':blast<CR>', opts.nore)
vim.keymap.set('n', 'bk', ':bprevious<CR>', opts.nore)
vim.keymap.set('n', 'bl', ':bnext<CR>', opts.nore)
vim.keymap.set('n', 'bc', ':bd<CR>', opts.nore)

-- Short write, quit
vim.keymap.set('n', '<leader>q', ':q<CR>', opts.nore)
vim.keymap.set('n', 'bw', ':w<CR>', opts.nore)
vim.keymap.set('n', '<leader>wq', ':wq<CR>', opts.nore)

--Move to begin/end word of line
vim.keymap.set('', 'g;', 'g_', opts.nore)
vim.keymap.set('', 'gj', '^', opts.nore)

--Avoid break out nvim
vim.keymap.set('n', '<C-c>', '<Esc>', opts.nore)

--Paste without loss previous text
vim.keymap.set('x', '<leader>p', '\"_dp', opts.nore)

--Copy,Paste in the system clipboard
--Use: checkhealth to check supported system clipboard
vim.keymap.set('n', '<C-y>', '"+y', opts.nore)
vim.keymap.set('v', '<C-y>', '"+y', opts.nore)
vim.keymap.set('n', '<C-p>', '"+p', opts.nore)
vim.keymap.set('i', '<C-p>', '<Esc>"+pa', opts.nore)

--Go to next/prev word in INSERT
vim.keymap.set('i', '<A-j>', '<Esc>i', opts.nore)
vim.keymap.set('i', '<A-;>', '<Esc>la', opts.nore)

--Repeat find letter command
vim.keymap.set('n', "'", ';', opts.nore)

--Keep cursor centered
vim.keymap.set('n', 'n', 'nzzzv', opts.nore)
vim.keymap.set('n', 'N', 'Nzzzv', opts.nore)
vim.keymap.set('n', 'J', 'mmJ`m', opts.nore)
vim.keymap.set('n', 'gJ', 'mmgJ`m', opts.nore)

-- NOTE: the following doesn't work for some reason
-- vim.keymap.set('n', '<C-u>', '<C-u>zz', opts.nore)
-- vim.keymap.set('n', '<C-d>', '<C-d>zz', opts.nore)

--Undo break point
vim.keymap.set('i', ',', ',<C-g>u', opts.nore)
vim.keymap.set('i', '.', '.<C-g>u', opts.nore)
vim.keymap.set('i', '!', '!<C-g>u', opts.nore)
vim.keymap.set('i', '?', '?<C-g>u', opts.nore)
vim.keymap.set('i', ':', ':<C-g>u', opts.nore)
vim.keymap.set('i', ';', ';<C-g>u', opts.nore)
-- vim.keymap.set('i',' ',' <C-g>u',opts.nore)

--Undo in insert mode
vim.keymap.set('i', '<A-u>', '<Esc>ua', opts.nore)

--Moving line of text
vim.keymap.set('i', '<A-k>', '<Esc>:m.+1<CR>==a', opts.nore)
vim.keymap.set('i', '<A-l>', '<Esc>:m.-2<CR>==a', opts.nore)
vim.keymap.set('n', '<A-l>', ':m.-2<CR>==', opts.nore)
vim.keymap.set('n', '<A-k>', ':m.+1<CR>==', opts.nore)
vim.keymap.set('v', '<A-l>', ":m '<-2<CR>gv=gv", opts.nore)
vim.keymap.set('v', '<A-k>', ":m '>+1<CR>gv=gv", opts.nore)

--Re-visual after indent
vim.keymap.set('v', '>', '>gv=gv', opts.nore)
vim.keymap.set('v', '<', '<gv=gv', opts.nore)
