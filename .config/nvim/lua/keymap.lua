vim.g.mapleader = ' '

local map = vim.api.nvim_set_keymap

local opts = {}
opts.nore = {noremap = true}

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

--Move to begin/end of line
map('','g;','$',{})
map('','gj','^',{})

--Avoid break out nvim
map('n','<C-c>','<Esc>',opts.nore)
