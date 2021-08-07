" Escaper INSERT mode
inoremap jk <Esc>

" Jump next of surrounded pair
inoremap <C-e> <Esc>%%a

" Remap hjkl -> jkl;
noremap ; l
noremap l k
noremap k j
noremap j h

nnoremap g; $
nnoremap gj ^

" Save, Quit
nnoremap <C-s> :w<CR>
nnoremap <C-q> :wq<CR>

" Avoid break program
nnoremap <C-c> <Esc>

nnoremap <C-t> :NERDTreeToggle<CR><C-w>j

