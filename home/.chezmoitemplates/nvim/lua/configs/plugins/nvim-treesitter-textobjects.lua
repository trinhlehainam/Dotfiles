local textobjects = require('nvim-treesitter-textobjects')

textobjects.setup({
  select = {
    -- Automatically jump forward to textobj, similar to targets.vim
    lookahead = true,
    -- You can choose the select mode (default is charwise 'v')
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * method: eg 'v' or 'o'
    -- and should return the mode ('v', 'V', or '<c-v>') or a table
    -- mapping query_strings to modes.
    selection_modes = {
      ['@parameter.outer'] = 'v', -- charwise
      ['@function.outer'] = 'V', -- linewise
      -- ['@class.outer'] = '<c-v>', -- blockwise
    },
    -- If you set this to `true` (default is `false`) then any textobject is
    -- extended to include preceding or succeeding whitespace. Succeeding
    -- whitespace has priority in order to act similarly to eg the built-in
    -- `ap`.
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * selection_mode: eg 'v'
    -- and should return true of false
    include_surrounding_whitespace = false,
  },
  move = {
    -- whether to set jumps in the jumplist
    set_jumps = true,
  },
})

-- keymaps
-- Text objects: select
local select = require('nvim-treesitter-textobjects.select')
-- You can use the capture groups defined in `textobjects.scm`
vim.keymap.set({ 'x', 'o' }, 'am', function()
  select.select_textobject('@function.outer', 'textobjects')
end)
vim.keymap.set({ 'x', 'o' }, 'im', function()
  select.select_textobject('@function.inner', 'textobjects')
end)
vim.keymap.set({ 'x', 'o' }, 'ac', function()
  select.select_textobject('@class.outer', 'textobjects')
end)
vim.keymap.set({ 'x', 'o' }, 'ic', function()
  select.select_textobject('@class.inner', 'textobjects')
end)
-- You can also use captures from other query groups like `locals.scm`
vim.keymap.set({ 'x', 'o' }, 'as', function()
  select.select_textobject('@local.scope', 'locals')
end)
--- Text objects: swap
local swap = require('nvim-treesitter-textobjects.swap')
vim.keymap.set('n', '<leader>a', function()
  swap.swap_next('@parameter.inner')
end)
vim.keymap.set('n', '<leader>A', function()
  swap.swap_previous('@parameter.outer')
end)
-- Text objects: move
local move = require('nvim-treesitter-textobjects.move')
-- You can use the capture groups defined in `textobjects.scm`
vim.keymap.set({ 'n', 'x', 'o' }, ']m', function()
  move.goto_next_start('@function.outer', 'textobjects')
end)
vim.keymap.set({ 'n', 'x', 'o' }, ']]', function()
  move.goto_next_start('@class.outer', 'textobjects')
end)
-- You can also pass a list to group multiple queries.
vim.keymap.set({ 'n', 'x', 'o' }, ']o', function()
  move.goto_next_start({ '@loop.inner', '@loop.outer' }, 'textobjects')
end)
-- You can also use captures from other query groups like `locals.scm` or `folds.scm`
vim.keymap.set({ 'n', 'x', 'o' }, ']s', function()
  move.goto_next_start('@local.scope', 'locals')
end)
vim.keymap.set({ 'n', 'x', 'o' }, ']z', function()
  move.goto_next_start('@fold', 'folds')
end)

vim.keymap.set({ 'n', 'x', 'o' }, ']M', function()
  move.goto_next_end('@function.outer', 'textobjects')
end)
vim.keymap.set({ 'n', 'x', 'o' }, '][', function()
  move.goto_next_end('@class.outer', 'textobjects')
end)

vim.keymap.set({ 'n', 'x', 'o' }, '[m', function()
  move.goto_previous_start('@function.outer', 'textobjects')
end)
vim.keymap.set({ 'n', 'x', 'o' }, '[[', function()
  move.goto_previous_start('@class.outer', 'textobjects')
end)

vim.keymap.set({ 'n', 'x', 'o' }, '[M', function()
  move.goto_previous_end('@function.outer', 'textobjects')
end)
vim.keymap.set({ 'n', 'x', 'o' }, '[]', function()
  move.goto_previous_end('@class.outer', 'textobjects')
end)

-- Go to either the start or the end, whichever is closer.
-- Use if you want more granular movements
vim.keymap.set({ 'n', 'x', 'o' }, ']d', function()
  move.goto_next('@conditional.outer', 'textobjects')
end)
vim.keymap.set({ 'n', 'x', 'o' }, '[d', function()
  move.goto_previous('@conditional.outer', 'textobjects')
end)

-- Repeat movement with ; and ,
local repeatable_move = require('nvim-treesitter-textobjects.repeatable_move')
-- ensure ; goes forward and , goes backward regardless of the last direction
vim.keymap.set({ 'n', 'x', 'o' }, ';', repeatable_move.repeat_last_move_next)
vim.keymap.set({ 'n', 'x', 'o' }, ',', repeatable_move.repeat_last_move_previous)

-- vim way: ; goes to the direction you were moving.
-- vim.keymap.set({ "n", "x", "o" }, ";", repeatable_move.repeat_last_move)
-- vim.keymap.set({ "n", "x", "o" }, ",", repeatable_move.repeat_last_move_opposite)

-- Optionally, make builtin f, F, t, T also repeatable with ; and ,
vim.keymap.set({ 'n', 'x', 'o' }, 'f', repeatable_move.builtin_f_expr, { expr = true })
vim.keymap.set({ 'n', 'x', 'o' }, 'F', repeatable_move.builtin_F_expr, { expr = true })
vim.keymap.set({ 'n', 'x', 'o' }, 't', repeatable_move.builtin_t_expr, { expr = true })
vim.keymap.set({ 'n', 'x', 'o' }, 'T', repeatable_move.builtin_T_expr, { expr = true })
