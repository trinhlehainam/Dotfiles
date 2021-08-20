local saga = require 'lspsaga'

-- add your config value here
-- default value
-- use_saga_diagnostic_sign = true
-- error_sign = '',
-- warn_sign = '',
-- hint_sign = '',
-- infor_sign = '',
-- dianostic_header_icon = '   ',
-- code_action_icon = ' ',
-- code_action_prompt = {
--   enable = true,
--   sign = true,
--   sign_priority = 20,
--   virtual_text = true,
-- },
-- finder_definition_icon = '  ',
-- finder_reference_icon = '  ',
-- max_preview_lines = 10, -- preview lines of lsp_finder and definition preview
-- finder_action_keys = {
--   open = 'o', vsplit = 's',split = 'i',quit = 'q',scroll_down = '<C-f>', scroll_up = '<C-b>' -- quit can be a table
-- },
-- code_action_keys = {
--   quit = 'q',exec = '<CR>'
-- },
-- rename_action_keys = {
--   quit = '<C-c>',exec = '<CR>'  -- quit can be a table
-- },
-- definition_preview_icon = '  '
-- "single" "double" "round" "plus"
-- border_style = "single"
-- rename_prompt_prefix = '➤',
-- if you don't use nvim-lspconfig you must pass your server name and
-- the related filetypes into this table
-- like server_filetype_map = {metals = {'sbt', 'scala'}}
-- server_filetype_map = {}

--[[ saga.init_lsp_saga {
} ]]

saga.init_lsp_saga()

local keymap = vim.api.nvim_set_keymap
local opts = {silent = true, noremap = true}

--lsp provider to find the cursor word definition and reference
keymap('n', 'gh', ':Lspsaga lsp_finder<CR>', opts)

-- code action
keymap('n','<leader>ca',':Lspsaga code_action<CR>',opts)
keymap('v','<leader>ca',':<C-U>Lspsaga range_code_action<CR>',opts)

-- show hover doc
keymap('n', 'K', ':Lspsaga hover_doc<CR>', opts)
keymap('n', '<C-k>', "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(1)<CR>", opts)
keymap('n', '<C-l>', "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(-1)<CR>", opts)

-- rename
keymap('n','rn',':Lspsaga rename<CR>',opts)

-- preview definition
keymap('n','gd', ':Lspsaga preview_definition<CR>', opts)

-- DIAGNOSTIC
-- show
keymap('n','<leader>d',':Lspsaga show_line_diagnostics<CR>',opts)
-- command
keymap('n','[d',':Lspsaga diagnostic_jump_next<CR>',opts)
keymap('n',']d',':Lspsaga diagnostic_jump_prev<CR>',opts)
