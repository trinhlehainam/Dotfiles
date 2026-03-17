local init_path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')
local test_root = vim.fn.fnamemodify(init_path, ':h')
local repo_root = vim.fn.fnamemodify(test_root, ':h:h')
local plenary_dir = vim.env.PLENARY_DIR ~= '' and vim.env.PLENARY_DIR or (vim.fn.stdpath('data') .. '/lazy/plenary.nvim')
local codesettings_dir = vim.env.CODESETTINGS_DIR ~= '' and vim.env.CODESETTINGS_DIR
  or (vim.fn.stdpath('data') .. '/lazy/codesettings.nvim')

if vim.fn.isdirectory(plenary_dir) == 0 then
  vim.api.nvim_err_writeln('plenary.nvim not found at ' .. plenary_dir)
  vim.cmd.cquit({ count = 1 })
end

if vim.fn.isdirectory(codesettings_dir) == 0 then
  vim.api.nvim_err_writeln('codesettings.nvim not found at ' .. codesettings_dir)
  vim.cmd.cquit({ count = 1 })
end

vim.g.project_settings_test_repo_root = repo_root
vim.g.project_settings_test_plenary_dir = plenary_dir
vim.g.project_settings_test_codesettings_dir = codesettings_dir

vim.cmd('cd ' .. vim.fn.fnameescape(repo_root))
vim.opt.runtimepath:prepend(repo_root)
vim.opt.runtimepath:prepend(plenary_dir)
vim.opt.runtimepath:prepend(codesettings_dir)

vim.opt.packpath = ''
vim.opt.shadafile = 'NONE'
vim.opt.swapfile = false
vim.opt.more = false
vim.opt.shortmess:append('I')

vim.cmd('runtime plugin/plenary.vim')

vim.o.verbose = 0
vim.o.undofile = false

package.path = table.concat({
  repo_root .. '/tests/plenary/helpers/?.lua',
  repo_root .. '/tests/plenary/helpers/?/init.lua',
  package.path,
}, ';')

vim.cmd('filetype on')
