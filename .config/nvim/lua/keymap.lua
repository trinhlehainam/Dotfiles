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

--Move to begin/end of line
map('','g;','$',{})
map('','gj','^',{})

--Avoid break out nvim
map('n','<C-c>','<Esc>',opts.nore)





