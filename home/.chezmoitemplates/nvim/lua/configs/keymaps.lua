-- ============================================================================
-- NEOVIM KEYMAPS CONFIGURATION
-- ============================================================================
--
-- This file contains custom keybindings for an enhanced Neovim workflow.
--
-- Key principles:
-- - Leader key is <Space> for ergonomic custom commands
-- - Consistent split navigation (normal/terminal) via `smart-splits` when available
-- - Vi-like navigation patterns where possible
-- - Quick escape mechanisms for insert/terminal modes
--
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Leader Key Configuration
-- ----------------------------------------------------------------------------

-- Set <Space> as the leader key for custom commands
-- This must happen before plugins are loaded to ensure correct behavior
-- See `:help mapleader` for more information
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ----------------------------------------------------------------------------
-- Keymap Options
-- ----------------------------------------------------------------------------

-- Define common keymap options for consistency
local opts = {}
opts.nore = { noremap = true, silent = true } -- Non-recursive, silent mappings

-- ============================================================================
-- CORE NAVIGATION & MOVEMENT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Leader Key Behavior
-- ----------------------------------------------------------------------------

-- Disable space in normal and visual mode (prevents conflicts with leader)
-- See `:help vim.keymap.set()` for keymap documentation
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- ----------------------------------------------------------------------------
-- Enhanced Line Navigation
-- ----------------------------------------------------------------------------

-- Smart line movement that respects word wrap
-- When no count is given, move by display lines (gj/gk)
-- When count is given, move by actual lines (j/k)
-- This makes navigation more intuitive with wrapped text
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- ----------------------------------------------------------------------------
-- Enhanced Yank/Copy Behavior
-- ----------------------------------------------------------------------------

-- Make Y consistent with D and C (yank to end of line)
-- By default, Y yanks the whole line (same as yy)
-- This makes Y yank from cursor to end of line (like D and C)
vim.keymap.set('n', 'Y', 'yg_', opts.nore)

-- ----------------------------------------------------------------------------
-- Key Remapping for Better Workflow
-- ----------------------------------------------------------------------------

-- Disable 's' and 'S' in normal mode to free them for other uses
-- 's' normally deletes character and enters insert mode (use 'cl' instead)
-- 'S' normally deletes line and enters insert mode (use 'cc' instead)
vim.keymap.set('n', 's', '', opts.nore)
vim.keymap.set('n', 'S', '', opts.nore)

-- ----------------------------------------------------------------------------
-- Insert Mode Escape Mechanisms
-- ----------------------------------------------------------------------------

-- Quick escape from insert mode using 'jk' sequence
-- Alternative to reaching for the Esc key, more ergonomic
vim.keymap.set('i', 'jk', '<Esc>', opts.nore)

-- Jump to matching closing delimiter in insert mode
-- Navigates to the end of surrounding pairs: () [] {}
-- Press <C-e> to jump to the matching closing delimiter
-- Example: cursor inside "te|xt(some)" -> <C-e> -> "text(|some)"
vim.keymap.set('i', '<C-e>', '<Esc>%%a', opts.nore)

-- ----------------------------------------------------------------------------
-- Terminal Mode Navigation (smart-splits aware)
-- ----------------------------------------------------------------------------
--
-- Terminal buffers run in "terminal-mode", so most normal-mode mappings don't
-- apply. Here we add a small, consistent set of terminal mappings and (when
-- installed) hand off split movement to `smart-splits`.
--
-- Integration Points:
-- 1. Works with Neovim's built-in terminal and toggleterm.nvim
-- 2. Uses `smart-splits` when available for consistent split navigation
--    (and optionally tmux-aware cursor moves, if configured there)
-- 3. Falls back to plain Vim window navigation when `smart-splits` isn't loaded
--
-- Key Behaviors:
-- - jk: Leave terminal-mode (same "jk" escape as insert mode)
-- - Ctrl-h/j/k/l: Move across splits, and possibly tmux panes via smart-splits
--
-- Reference: https://github.com/akinsho/toggleterm.nvim?tab=readme-ov-file#terminal-window-mappings
-- ----------------------------------------------------------------------------

local function set_terminal_keymaps()
  -- Buffer-local options for terminal keymaps
  local terminal_opts = { buffer = 0 }

  -- Quick escape from terminal mode using 'jk' (matches insert mode escape)
  vim.keymap.set('t', 'jk', [[<C-\><C-n>]], terminal_opts)

  local ok, smart_splits = pcall(require, 'smart-splits')
  if not ok then
    -- Fallback: Standard Vim window navigation
    -- Exit terminal mode, then use standard window movement commands
    vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], terminal_opts)
    vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], terminal_opts)
    vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], terminal_opts)
    vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], terminal_opts)
  else
    -- `smart-splits` active: use its cursor movers.
    -- If you've enabled tmux integration in smart-splits, these can also cross
    -- tmux pane boundaries; otherwise they behave like split navigation.
    vim.keymap.set('t', '<C-h>', smart_splits.move_cursor_left, terminal_opts)
    vim.keymap.set('t', '<C-j>', smart_splits.move_cursor_down, terminal_opts)
    vim.keymap.set('t', '<C-k>', smart_splits.move_cursor_up, terminal_opts)
    vim.keymap.set('t', '<C-l>', smart_splits.move_cursor_right, terminal_opts)
  end
end

-- Apply terminal keymaps to all terminal buffers
-- This autocmd ensures our keymaps are set whenever a terminal is opened,
-- whether it's a built-in terminal, toggleterm, or any other terminal emulator
--
-- For toggleterm-specific mappings, use pattern: term://*toggleterm#*
vim.api.nvim_create_autocmd('TermOpen', {
  pattern = 'term://*',
  callback = set_terminal_keymaps,
  desc = 'Set terminal navigation keymaps',
})

-- ============================================================================
-- TAB MANAGEMENT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tab Navigation
-- ----------------------------------------------------------------------------

-- Efficient tab navigation using 't' prefix
-- Mnemonic: t + action/direction
-- tn: Tab new (create new tab)
-- tk: Tab next (k for up/forward)
-- tj: Tab previous (j for down/back)
-- tc: Tab close (close current tab)
-- th: Tab home (first tab)
-- tl: Tab last (last tab)
vim.keymap.set('n', 'tn', ':tabnew<CR>', opts.nore) -- Create new tab
vim.keymap.set('n', 'tk', ':tabnext<CR>', opts.nore) -- Go to next tab
vim.keymap.set('n', 'tj', ':tabprevious<CR>', opts.nore) -- Go to previous tab
vim.keymap.set('n', 'tc', ':tabclose<CR>', opts.nore) -- Close current tab
vim.keymap.set('n', 'th', ':tabfirst<CR>', opts.nore) -- Go to first tab
vim.keymap.set('n', 'tl', ':tablast<CR>', opts.nore) -- Go to last tab

-- ============================================================================
-- ENHANCED MOVEMENT & NAVIGATION
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Terminal Integration
-- ----------------------------------------------------------------------------

-- Prevent accidental terminal interruption.
-- Map Ctrl-c to Esc so you don't send SIGINT to Neovim by mistake.
-- Handy when your muscle memory is Ctrl-c (and when running inside terminal multiplexers).
vim.keymap.set('n', '<C-c>', '<Esc>', opts.nore)

-- ============================================================================
-- CLIPBOARD & PASTE OPERATIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Smart Paste Operations
-- ----------------------------------------------------------------------------

-- Paste without losing the current register content
-- When pasting over selected text, preserve the original yanked content
-- Uses the "black hole" register (_) to discard the replaced text
vim.keymap.set('x', '<leader>p', '"_dp', opts.nore)

-- ----------------------------------------------------------------------------
-- System Clipboard Integration
-- ----------------------------------------------------------------------------

-- System clipboard operations using Ctrl key combinations
-- Note: Use :checkhealth to verify system clipboard support
-- Requires clipboard provider (xclip, wl-clipboard, pbcopy, etc.)
--
-- Ctrl-y: Copy to system clipboard (yank)
-- Ctrl-p: Paste from system clipboard
vim.keymap.set('n', '<C-y>', '"+y', opts.nore) -- Copy to system clipboard (normal)
vim.keymap.set('v', '<C-y>', '"+y', opts.nore) -- Copy to system clipboard (visual)
vim.keymap.set('n', '<C-p>', '"+p', opts.nore) -- Paste from system clipboard (normal)
vim.keymap.set('i', '<C-p>', '<Esc>"+pa', opts.nore) -- Paste from system clipboard (insert)

-- ============================================================================
-- INSERT MODE ENHANCEMENTS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Character Navigation in Insert Mode
-- ----------------------------------------------------------------------------

-- Navigate by single characters while staying in insert mode
-- Alt-h: Move one character to the left
-- Alt-l: Move one character to the right
-- Useful for quick cursor adjustments without leaving insert mode
vim.keymap.set('i', '<A-h>', '<Esc>hi', opts.nore) -- Move one character left
vim.keymap.set('i', '<A-l>', '<Esc>la', opts.nore) -- Move one character right

-- ============================================================================
-- SEARCH & NAVIGATION ENHANCEMENTS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Centered Search Results
-- ----------------------------------------------------------------------------

-- Keep cursor centered when jumping between search results
-- Automatically centers the screen and opens folds
-- n: Next search result (centered)
-- N: Previous search result (centered)
vim.keymap.set('n', 'n', 'nzzzv', opts.nore) -- Next search match (centered)
vim.keymap.set('n', 'N', 'Nzzzv', opts.nore) -- Previous search match (centered)

-- ----------------------------------------------------------------------------
-- Enhanced Line Joining
-- ----------------------------------------------------------------------------

-- Join lines with cursor position preservation
-- Uses mark to remember cursor position and return to it after joining
-- J: Join lines (cursor stays in place)
-- gJ: Join lines without space (cursor stays in place)
vim.keymap.set('n', 'J', 'mmJ`m', opts.nore) -- Join lines, preserve cursor position
vim.keymap.set('n', 'gJ', 'mmgJ`m', opts.nore) -- Join lines without space, preserve cursor

-- ----------------------------------------------------------------------------
-- Centered Scrolling
-- ----------------------------------------------------------------------------

-- Center screen when scrolling up/down by half page
-- NOTE: These mappings may not work in all terminal configurations
-- due to terminal key interpretation differences
vim.keymap.set('n', '<C-u>', '<C-u>zz', opts.nore) -- Scroll up half page (centered)
vim.keymap.set('n', '<C-d>', '<C-d>zz', opts.nore) -- Scroll down half page (centered)

-- ============================================================================
-- UNDO & HISTORY MANAGEMENT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Intelligent Undo Break Points
-- ----------------------------------------------------------------------------

-- Create undo break points at natural stopping points in insert mode
-- This allows for more granular undo operations instead of undoing entire
-- insert sessions. Each punctuation mark creates a new undo point.
--
-- <C-g>u breaks the undo sequence at the current position
vim.keymap.set('i', ',', ',<C-g>u', opts.nore) -- Comma creates undo break point
vim.keymap.set('i', '.', '.<C-g>u', opts.nore) -- Period creates undo break point
vim.keymap.set('i', '!', '!<C-g>u', opts.nore) -- Exclamation creates undo break point
vim.keymap.set('i', '?', '?<C-g>u', opts.nore) -- Question mark creates undo break point
vim.keymap.set('i', ':', ':<C-g>u', opts.nore) -- Colon creates undo break point
vim.keymap.set('i', ';', ';<C-g>u', opts.nore) -- Semicolon creates undo break point
-- Space also creates break points but can be intrusive:
-- vim.keymap.set('i', ' ', ' <C-g>u', opts.nore)

-- ----------------------------------------------------------------------------
-- Insert Mode Undo
-- ----------------------------------------------------------------------------

-- Quick undo from insert mode without leaving insert
-- Alt-u: Undo last change and return to insert mode
-- Useful for quick corrections during typing
vim.keymap.set('i', '<A-u>', '<Esc>ua', opts.nore)

-- ============================================================================
-- TEXT MANIPULATION
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Line Movement
-- ----------------------------------------------------------------------------

-- Move lines up/down with automatic indentation fixing
-- Works in insert, normal, and visual modes
-- Alt-k: Move line(s) up
-- Alt-j: Move line(s) down
--
-- The == part re-indents the moved lines to maintain proper formatting
vim.keymap.set('i', '<A-k>', '<Esc>:m.-2<CR>==a', opts.nore) -- Move line up (insert mode)
vim.keymap.set('i', '<A-j>', '<Esc>:m.+1<CR>==a', opts.nore) -- Move line down (insert mode)
vim.keymap.set('n', '<A-k>', ':m.-2<CR>==', opts.nore) -- Move line up (normal mode)
vim.keymap.set('n', '<A-j>', ':m.+1<CR>==', opts.nore) -- Move line down (normal mode)
vim.keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", opts.nore) -- Move selection up (visual mode)
vim.keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", opts.nore) -- Move selection down (visual mode)

-- ----------------------------------------------------------------------------
-- Smart Indentation
-- ----------------------------------------------------------------------------

-- Maintain visual selection after indenting
-- After indenting with > or <, automatically:
-- 1. Re-select the same text (gv)
-- 2. Re-indent properly (=)
-- 3. Re-select again (gv) for continued indenting
-- This allows for multiple indentation operations without re-selecting
vim.keymap.set('v', '>', '>gv=gv', opts.nore) -- Indent right and maintain selection
vim.keymap.set('v', '<', '<gv=gv', opts.nore) -- Indent left and maintain selection

-- ============================================================================
-- TOGGLE OPTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Spell Check Toggle
-- ----------------------------------------------------------------------------

-- Toggle spell checking on/off
-- <leader>ts: Toggle spell (mnemonic: t = toggle, s = spell)
vim.keymap.set('n', '<leader>ts', function()
  vim.o.spell = not vim.o.spell
end, { noremap = true, silent = true, desc = 'Toggle spell check' })

-- ============================================================================
-- END OF KEYMAPS CONFIGURATION
-- ============================================================================
