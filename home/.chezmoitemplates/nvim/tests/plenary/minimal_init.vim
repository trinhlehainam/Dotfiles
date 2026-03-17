let s:test_root = fnamemodify(expand('<sfile>:p'), ':h')
let s:repo_root = fnamemodify(s:test_root, ':h:h')
let s:plenary_dir = empty($PLENARY_DIR) ? stdpath('data') . '/lazy/plenary.nvim' : $PLENARY_DIR

if !isdirectory(s:plenary_dir)
  echoerr 'plenary.nvim not found at ' . s:plenary_dir
  cquit 1
endif

let g:project_settings_test_repo_root = s:repo_root
let g:project_settings_test_plenary_dir = s:plenary_dir

execute 'cd ' . fnameescape(s:repo_root)
execute 'set runtimepath^=' . fnameescape(s:repo_root)
execute 'set runtimepath^=' . fnameescape(s:plenary_dir)

set packpath=
set shadafile=NONE
set noswapfile
set nomore
set shortmess+=I

runtime plugin/plenary.vim

lua << EOF
vim.o.verbose = 0
vim.o.undofile = false

local repo = vim.g.project_settings_test_repo_root
package.path = table.concat({
  repo .. '/tests/plenary/helpers/?.lua',
  repo .. '/tests/plenary/helpers/?/init.lua',
  package.path,
}, ';')
EOF

filetype on
