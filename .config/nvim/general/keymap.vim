let g:mapleader = ' '

" Escape INSERT mode
inoremap jk <Esc>

" Jump next of surrounded pair
inoremap <C-e> <Esc>%%a

" Remap hjkl -> jkl;
noremap ; l
noremap l k
noremap k j
noremap j h

" Remap window navigation
noremap <C-w>; <C-w>l
noremap <C-w>l <C-w>k
noremap <C-w>k <C-w>j
noremap <C-w>j <C-w>h

" Go begin , end of line
nnoremap g; $
nnoremap gj ^

" Avoid break program
nnoremap <C-c> <Esc>



