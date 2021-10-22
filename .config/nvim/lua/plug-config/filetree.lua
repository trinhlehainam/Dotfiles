require'nvim-tree'.setup {}

local keymap = vim.api.nvim_set_keymap
local opts = {silent = true, noremap = true}

keymap('n', 'tt', ':NvimTreeToggle<CR>', opts);
