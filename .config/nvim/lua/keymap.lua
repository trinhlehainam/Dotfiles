vim.g.mapleader = ' '

local map = vim.api.nvim_set_keymap

local opts = {}
opts.nore = {noremap = true, silent = true}

-- Copy to the end of line
map('n','Y','yg_',opts.nore)

-- DELETE keys
map('n','s','',opts.nore)
map('n','S','',opts.nore)
-- Quick escape INSERT mode
map('i','jk','<Esc>', opts.nore)

--Jump out of surround pairs
map('i','<C-e>','<Esc>%%a', opts.nore)

--Change hjkl -> jkl;
map('',';','l', opts.nore)
map('','l','k', opts.nore)
map('','k','j', opts.nore)
map('','j','h', opts.nore)

--Window Navigation
map('n','<leader>;','<C-w>l',opts.nore)
map('n','<leader>l','<C-w>k',opts.nore)
map('n','<leader>k','<C-w>j',opts.nore)
map('n','<leader>j','<C-w>h',opts.nore)
map('n','<leader>q','<C-w>c',opts.nore)

--Tab Navigation
map('n','tj',':tabfirst<CR>',opts.nore)
map('n','t;',':tablast<CR>',opts.nore)
map('n','tk',':tabprev<CR>',opts.nore)
map('n','tl',':tabnext<CR>',opts.nore)
map('n','tq',':tabclose<CR>',opts.nore)
map('n','t1','1gt',opts.nore)
map('n','t2','2gt',opts.nore)
map('n','t3','3gt',opts.nore)
map('n','t4','4gt',opts.nore)
map('n','t5','5gt',opts.nore)
map('n','t6','6gt',opts.nore)
map('n','t7','7gt',opts.nore)

--Move to begin/end word of line
map('','g;','g_',{})
map('','gj','^',{})

--Avoid break out nvim
map('n','<C-c>','<Esc>',opts.nore)

--Copy,Paste in the clipboard
--Use :checkhealth to check supported system clipboard
map('n','<C-y>','"+y',opts.nore)
map('v','<C-y>','"+y',opts.nore)
map('n','<C-p>','"+p',opts.nore)
map('i','<C-p>','<Esc>"+p',opts.nore)

--Go to next/prev word in INSERT
map('i','<A-j>','<Esc>i',opts.nore)
map('i','<A-;>','<Esc>la',opts.nore)

--Repeat find letter command
map('n',"'",';',opts.nore)

--Keep cursor centered
map('n','n','nzzzv',opts.nore)
map('n','N','Nzzzv',opts.nore)
map('n','J','mmJ`m',opts.nore)
map('n','gJ','mmgJ`m',opts.nore)

--Undo break point
map('i',',',',<C-g>u',opts.nore)
map('i','.','.<C-g>u',opts.nore)
map('i','!','!<C-g>u',opts.nore)
map('i','?','?<C-g>u',opts.nore)
map('i',' ',' <C-g>u',opts.nore)

--Undo in insert mode
-- map('i','<A-u>','<Esc>ua',opts.nore)

--Moving text
map('i','<A-k>','<Esc>:m.+1<CR>==a',opts.nore)
map('i','<A-l>','<Esc>:m.-2<CR>==a',opts.nore)
map('n','<A-l>',':m.-2<CR>==',opts.nore)
map('n','<A-k>',':m.+1<CR>==',opts.nore)
map('v','<A-l>',":m '<-2<CR>gv=gv",opts.nore)
map('v','<A-k>',":m '>+1<CR>gv=gv",opts.nore)
