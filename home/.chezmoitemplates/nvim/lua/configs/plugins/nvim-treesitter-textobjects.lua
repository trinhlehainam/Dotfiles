-- ============================================================================
-- TREESITTER TEXTOBJECTS
-- ============================================================================
-- Syntax-aware text objects and motions using treesitter queries.
--
-- KEYMAPS SUMMARY:
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ SELECT (x,o)   │ af/if=func  ac/ic=class  ai/ii=if  ao/io=loop  as=scope │
-- │ SWAP (n)       │ <A-l>=swap right  <A-h>=swap left                        │
-- │ GOTO (n,x,o)   │ ]f/[f=func  ]]/[[=class  ]i/[i=if  ]o/[o=loop           │
-- │ REPEAT (n,x,o) │ ;=forward  ,=backward  f/F/t/T=enhanced find           │
-- └─────────────────────────────────────────────────────────────────────────┘
-- ============================================================================

local textobjects = require('nvim-treesitter-textobjects')

-- ── Setup ───────────────────────────────────────────────────────────────────

textobjects.setup({
  select = {
    lookahead = true, -- Jump forward to textobj (like targets.vim)
    selection_modes = {
      ['@parameter.outer'] = 'v', -- charwise
      ['@function.outer'] = 'V', -- linewise
    },
    include_surrounding_whitespace = false,
  },
  move = {
    set_jumps = true, -- Add to jumplist
  },
})

-- ============================================================================
-- SELECT TEXT OBJECTS (visual/operator-pending modes)
-- ============================================================================

local select = require('nvim-treesitter-textobjects.select')

-- Function text objects
vim.keymap.set({ 'x', 'o' }, 'af', function()
  select.select_textobject('@function.outer', 'textobjects')
end, { desc = 'Select outer function' })

vim.keymap.set({ 'x', 'o' }, 'if', function()
  select.select_textobject('@function.inner', 'textobjects')
end, { desc = 'Select inner function' })

-- Class text objects
vim.keymap.set({ 'x', 'o' }, 'ac', function()
  select.select_textobject('@class.outer', 'textobjects')
end, { desc = 'Select outer class' })

vim.keymap.set({ 'x', 'o' }, 'ic', function()
  select.select_textobject('@class.inner', 'textobjects')
end, { desc = 'Select inner class' })

-- Conditional text objects
vim.keymap.set({ 'x', 'o' }, 'ai', function()
  select.select_textobject('@conditional.outer', 'textobjects')
end, { desc = 'Select outer conditional' })

vim.keymap.set({ 'x', 'o' }, 'ii', function()
  select.select_textobject('@conditional.inner', 'textobjects')
end, { desc = 'Select inner conditional' })

-- Loop text objects
vim.keymap.set({ 'x', 'o' }, 'ao', function()
  select.select_textobject('@loop.outer', 'textobjects')
end, { desc = 'Select outer loop' })

vim.keymap.set({ 'x', 'o' }, 'io', function()
  select.select_textobject('@loop.inner', 'textobjects')
end, { desc = 'Select inner loop' })

-- Scope text object (locals.scm)
vim.keymap.set({ 'x', 'o' }, 'as', function()
  select.select_textobject('@local.scope', 'locals')
end, { desc = 'Select scope' })

-- ============================================================================
-- SWAP PARAMETERS (normal mode)
-- ============================================================================

local swap = require('nvim-treesitter-textobjects.swap')

-- Swap arguments horizontally (complements <A-j>/<A-k> line movement)
vim.keymap.set('n', '<A-l>', function()
  swap.swap_next('@parameter.inner')
end, { desc = 'Swap argument right' })

vim.keymap.set('n', '<A-h>', function()
  swap.swap_previous('@parameter.inner')
end, { desc = 'Swap argument left' })

-- ============================================================================
-- GOTO MOTIONS (normal/visual/operator-pending modes)
-- ============================================================================

local move = require('nvim-treesitter-textobjects.move')

-- ── Function Navigation ─────────────────────────────────────────────────────

vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
  move.goto_next_start('@function.outer', 'textobjects')
end, { desc = 'Next function start' })

vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
  move.goto_previous_start('@function.outer', 'textobjects')
end, { desc = 'Prev function start' })

vim.keymap.set({ 'n', 'x', 'o' }, ']F', function()
  move.goto_next_end('@function.outer', 'textobjects')
end, { desc = 'Next function end' })

vim.keymap.set({ 'n', 'x', 'o' }, '[F', function()
  move.goto_previous_end('@function.outer', 'textobjects')
end, { desc = 'Prev function end' })

-- ── Class Navigation ────────────────────────────────────────────────────────
-- NOTE: Overrides Vim's builtin section motions (intentional)

vim.keymap.set({ 'n', 'x', 'o' }, ']]', function()
  move.goto_next_start('@class.outer', 'textobjects')
end, { desc = 'Next class start' })

vim.keymap.set({ 'n', 'x', 'o' }, '[[', function()
  move.goto_previous_start('@class.outer', 'textobjects')
end, { desc = 'Prev class start' })

vim.keymap.set({ 'n', 'x', 'o' }, '][', function()
  move.goto_next_end('@class.outer', 'textobjects')
end, { desc = 'Next class end' })

vim.keymap.set({ 'n', 'x', 'o' }, '[]', function()
  move.goto_previous_end('@class.outer', 'textobjects')
end, { desc = 'Prev class end' })

-- ── Loop Navigation ─────────────────────────────────────────────────────────

vim.keymap.set({ 'n', 'x', 'o' }, ']o', function()
  move.goto_next_start('@loop.outer', 'textobjects')
end, { desc = 'Next loop start' })

vim.keymap.set({ 'n', 'x', 'o' }, '[o', function()
  move.goto_previous_start('@loop.outer', 'textobjects')
end, { desc = 'Prev loop start' })

vim.keymap.set({ 'n', 'x', 'o' }, ']O', function()
  move.goto_next_end('@loop.outer', 'textobjects')
end, { desc = 'Next loop end' })

vim.keymap.set({ 'n', 'x', 'o' }, '[O', function()
  move.goto_previous_end('@loop.outer', 'textobjects')
end, { desc = 'Prev loop end' })

-- ── Conditional Navigation ──────────────────────────────────────────────────
-- NOTE: Uses ]i/[i (not ]d/[d which conflicts with LSP diagnostic jump)

vim.keymap.set({ 'n', 'x', 'o' }, ']i', function()
  move.goto_next_start('@conditional.outer', 'textobjects')
end, { desc = 'Next conditional start' })

vim.keymap.set({ 'n', 'x', 'o' }, '[i', function()
  move.goto_previous_start('@conditional.outer', 'textobjects')
end, { desc = 'Prev conditional start' })

vim.keymap.set({ 'n', 'x', 'o' }, ']I', function()
  move.goto_next_end('@conditional.outer', 'textobjects')
end, { desc = 'Next conditional end' })

vim.keymap.set({ 'n', 'x', 'o' }, '[I', function()
  move.goto_previous_end('@conditional.outer', 'textobjects')
end, { desc = 'Prev conditional end' })

-- ── Scope Navigation ────────────────────────────────────────────────────────
-- NOTE: Uses ]S/[S (not ]s/[s which conflicts with Vim spell navigation)

vim.keymap.set({ 'n', 'x', 'o' }, ']S', function()
  move.goto_next_start('@local.scope', 'locals')
end, { desc = 'Next scope' })

vim.keymap.set({ 'n', 'x', 'o' }, '[S', function()
  move.goto_previous_start('@local.scope', 'locals')
end, { desc = 'Prev scope' })

-- ── Fold Navigation ─────────────────────────────────────────────────────────

vim.keymap.set({ 'n', 'x', 'o' }, ']z', function()
  move.goto_next_start('@fold', 'folds')
end, { desc = 'Next fold' })

vim.keymap.set({ 'n', 'x', 'o' }, '[z', function()
  move.goto_previous_start('@fold', 'folds')
end, { desc = 'Prev fold' })

-- ============================================================================
-- REPEATABLE MOTIONS
-- ============================================================================
-- Makes all treesitter motions repeatable with ; and ,
-- Also enhances builtin f/F/t/T to be repeatable

local repeatable_move = require('nvim-treesitter-textobjects.repeatable_move')

-- ; always goes forward, , always goes backward
vim.keymap.set(
  { 'n', 'x', 'o' },
  ';',
  repeatable_move.repeat_last_move_next,
  { desc = 'Repeat move forward' }
)
vim.keymap.set(
  { 'n', 'x', 'o' },
  ',',
  repeatable_move.repeat_last_move_previous,
  { desc = 'Repeat move backward' }
)

-- Make builtin f/F/t/T repeatable with ; and ,
vim.keymap.set(
  { 'n', 'x', 'o' },
  'f',
  repeatable_move.builtin_f_expr,
  { expr = true, desc = 'Find char forward' }
)
vim.keymap.set(
  { 'n', 'x', 'o' },
  'F',
  repeatable_move.builtin_F_expr,
  { expr = true, desc = 'Find char backward' }
)
vim.keymap.set(
  { 'n', 'x', 'o' },
  't',
  repeatable_move.builtin_t_expr,
  { expr = true, desc = 'Till char forward' }
)
vim.keymap.set(
  { 'n', 'x', 'o' },
  'T',
  repeatable_move.builtin_T_expr,
  { expr = true, desc = 'Till char backward' }
)
