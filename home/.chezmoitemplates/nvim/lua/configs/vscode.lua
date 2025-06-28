-- https://medium.com/@nikmas_dev/vscode-neovim-setup-keyboard-centric-powerful-reliable-clean-and-aesthetic-development-582d34297985
-- NOTE: vscode extensions and configurations
-- https://github.com/vscode-neovim/vscode-neovim
-- https://github.com/VSpaceCode/vscode-which-key
-- https://stackoverflow.com/a/64786469
-- https://code.visualstudio.com/docs/getstarted/keybindings

vim.opt.spelllang = 'en_us'
vim.opt.spell = false

local opts = {}

opts.nore = { noremap = true, silent = true }

vim.keymap.set('n', 'gcc', '<Plug>VSCodeCommentaryLine', opts.nore)
vim.keymap.set({ 'x', 'v' }, 'gc', '<Plug>VSCodeCommentary', opts.nore)
vim.keymap.set('n', '<leader>', "<Cmd>call VSCodeNotify('whichkey.show')<CR>", opts.nore)

--Buffer Navigation
vim.keymap.set('n', 'bh', ':Tabfirst<CR>', opts.nore)
vim.keymap.set('n', 'bl', ':Tablast<CR>', opts.nore)
vim.keymap.set('n', 'bj', ':Tabprevious<CR>', opts.nore)
vim.keymap.set('n', 'bk', ':Tabnext<CR>', opts.nore)
vim.keymap.set('n', 'bc', ':Tabclose<CR>', opts.nore)

vim.keymap.set(
  'n',
  '<leader>tt',
  "<Cmd>call VSCodeNotify('workbench.view.explorer')<CR>",
  opts.nore
)
vim.keymap.set('n', '<leader>/', "<Cmd>call VSCodeNotify('actions.find')<CR>", opts.nore)

-- Telescope
vim.keymap.set(
  'n',
  '<leader>sf',
  "<Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>",
  opts.nore
)
vim.keymap.set(
  'n',
  '<leader>sg',
  "<Cmd>call VSCodeNotify('workbench.action.findInFiles')<CR>",
  opts.nore
)

-- LSP
vim.keymap.set('n', 'grn', "<Cmd>call VSCodeNotify('editor.action.rename')<CR>", opts.nore)
vim.keymap.set('n', 'gra', "<Cmd>call VSCodeNotify('editor.action.quickFix')<CR>", opts.nore)
vim.keymap.set(
  'n',
  'grd',
  "<Cmd>call VSCodeNotify('editor.action.revealDefinition')<CR>",
  opts.nore
)
vim.keymap.set('n', 'grr', "<Cmd>call VSCodeNotify('editor.action.goToReferences')<CR>", opts.nore)
vim.keymap.set(
  'n',
  '[d',
  "<Cmd>call VSCodeNotify('editor.action.marker.nextInFiles')<CR>",
  opts.nore
)
vim.keymap.set(
  'n',
  ']d',
  "<Cmd>call VSCodeNotify('editor.action.marker.prevInFiles')<CR>",
  opts.nore
)

--Moving line of text
vim.keymap.set(
  { 'n', 'v', 'i' },
  '<A-k>',
  "<Cmd>call VSCodeNotify('editor.action.moveLinesUpAction')<CR>",
  opts.nore
)
vim.keymap.set(
  { 'n', 'v', 'i' },
  '<A-j>',
  "<Cmd>call VSCodeNotify('editor.action.moveLinesDownAction')<CR>",
  opts.nore
)
