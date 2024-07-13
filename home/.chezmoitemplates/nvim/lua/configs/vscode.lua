vim.opt.spelllang = "en_us"
vim.opt.spell = false

local opts = {}

opts.nore = { noremap = true, silent = true }

vim.keymap.set("n", "jk", "<C-c>", opts.nore)

vim.keymap.set("n", "gcc", "<Plug>VSCodeCommentaryLine", opts.nore)
vim.keymap.set({ "x", "v" }, "gc", "<Plug>VSCodeCommentary", opts.nore)
vim.keymap.set("n", "<leader>", "<Cmd>call VSCodeNotify('whichkey.show')<CR>", opts.nore)

--Buffer Navigation
vim.keymap.set("n", "bh", ":Tabfirst<CR>", opts.nore)
vim.keymap.set("n", "bl", ":Tablast<CR>", opts.nore)
vim.keymap.set("n", "bj", ":Tabprevious<CR>", opts.nore)
vim.keymap.set("n", "bk", ":Tabnext<CR>", opts.nore)
vim.keymap.set("n", "bc", ":Tabclose<CR>", opts.nore)

vim.keymap.set("n", "tt", "<Cmd>call VSCodeNotify('workbench.view.explorer')<CR>", opts.nore)
vim.keymap.set("n", "<leader>/", "<Cmd>call VSCodeNotify('actions.find')<CR>", opts.nore)

-- Telescope
vim.keymap.set("n", "<leader><leader>", "<Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>", opts.nore)
vim.keymap.set("n", "<leader>fg", "<Cmd>call VSCodeNotify('workbench.action.findInFiles')<CR>", opts.nore)

-- LSP
vim.keymap.set("n", "<leader>rn", "<Cmd>call VSCodeNotify('editor.action.rename')<CR>", opts.nore)
vim.keymap.set("n", "<leader>ca", "<Cmd>call VSCodeNotify('editor.action.quickFix')<CR>", opts.nore)
vim.keymap.set("n", "[d", "<Cmd>call VSCodeNotify('editor.action.marker.nextInFiles')<CR>", opts.nore)
vim.keymap.set("n", "]d", "<Cmd>call VSCodeNotify('editor.action.marker.prevInFiles')<CR>", opts.nore)

--Moving line of text
vim.keymap.set({ "n", "v", "i" }, "<A-k>", "<Cmd>call VSCodeNotify('editor.action.moveLinesUpAction')<CR>", opts.nore)
vim.keymap.set({ "n", "v", "i" }, "<A-j>", "<Cmd>call VSCodeNotify('editor.action.moveLinesDownAction')<CR>", opts.nore)
