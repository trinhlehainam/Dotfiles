-- ============================================================================
-- NEOVIM KEYMAPS CONFIGURATION
-- ============================================================================
--
-- This file contains custom keybindings for enhanced Neovim workflow.
-- Includes vim-tmux-navigator integration for seamless pane navigation.
--
-- Key principles:
-- - Leader key is <Space> for ergonomic access to custom commands
-- - Alt key combinations for window/split management (consistent with tmux)
-- - Vi-like navigation patterns where possible
-- - Quick escape mechanisms for insert mode
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

-- Quick jump to end of surrounding pairs in insert mode
-- Useful for escaping from quotes, brackets, parentheses
-- <C-e> jumps to end of current 'word' and continues in insert mode
vim.keymap.set('i', '<C-e>', '<Esc>%%a', opts.nore)

-- ----------------------------------------------------------------------------
-- Vim-Tmux Terminal Navigator Integration
-- ----------------------------------------------------------------------------

-- See https://github.com/akinsho/toggleterm.nvim?tab=readme-ov-file#terminal-window-mappings
function _G.set_terminal_keymaps()
  local opts = { buffer = 0 }
  vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
  vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
  -- Check if vim-tmux-navigator plugin is available
  -- See: https://github.com/christoomey/vim-tmux-navigator/blob/master/plugin/tmux_navigator.vim
  if vim.g.loaded_tmux_navigator == nil then
    vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], opts)
    vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], opts)
    vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], opts)
    vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], opts)
  else
    vim.keymap.set('t', '<C-h>', [[<cmd>TmuxNavigateLeft<CR>]], opts)
    vim.keymap.set('t', '<C-j>', [[<cmd>TmuxNavigateDown<CR>]], opts)
    vim.keymap.set('t', '<C-k>', [[<cmd>TmuxNavigateUp<CR>]], opts)
    vim.keymap.set('t', '<C-l>', [[<cmd>TmuxNavigateRight<CR>]], opts)
  end
end

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

-- ============================================================================
-- WINDOW & SPLIT MANAGEMENT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Split Resizing (Vim-Tmux Navigator Compatible)
-- ----------------------------------------------------------------------------

-- Window/split resize controls using Alt key combinations
-- These work seamlessly with tmux when vim-tmux-navigator is configured
--
-- IMPORTANT: Direction meanings (fixed from previous inversion):
-- Alt-,: Decrease width (move vertical border left)
-- Alt-.: Increase width (move vertical border right)
-- Alt-u: Decrease height (move horizontal border up)
-- Alt-d: Increase height (move horizontal border down)
--
-- Resize increment: 5 lines/columns for noticeable but controlled changes
vim.keymap.set('n', '<A-,>', '<c-w>5>', opts.nore) -- Increase width (move right border right)
vim.keymap.set('n', '<A-.>', '<c-w>5<', opts.nore) -- Decrease width (move right border left)
vim.keymap.set('n', '<A-u>', '<C-W>5+', opts.nore) -- Increase height (move bottom border down)
vim.keymap.set('n', '<A-d>', '<C-W>5-', opts.nore) -- Decrease height (move bottom border up)

-- ============================================================================
-- BUFFER & TAB MANAGEMENT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Buffer Navigation
-- ----------------------------------------------------------------------------

-- Efficient buffer navigation using 'b' prefix
-- Mnemonic: b + direction/action
-- bh: Buffer home (first buffer)
-- bl: Buffer last (last buffer)
-- bj: Buffer previous (j for down/back in list)
-- bk: Buffer next (k for up/forward in list)
-- bc: Buffer close (close current buffer)
vim.keymap.set('n', 'bh', ':bfirst<CR>', opts.nore) -- Go to first buffer
vim.keymap.set('n', 'bl', ':blast<CR>', opts.nore) -- Go to last buffer
vim.keymap.set('n', 'bj', ':bprevious<CR>', opts.nore) -- Go to previous buffer
vim.keymap.set('n', 'bk', ':bnext<CR>', opts.nore) -- Go to next buffer
vim.keymap.set('n', 'bc', ':bd<CR>', opts.nore) -- Close current buffer

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
-- Line-based Movement
-- ----------------------------------------------------------------------------

-- Enhanced line navigation (works in all modes)
-- gl: Go to last non-blank character (end of content)
-- gh: Go to first non-blank character (beginning of content)
-- More intuitive than default ^ and g_ commands
vim.keymap.set('', 'gl', 'g_', opts.nore) -- Go to last non-blank character
vim.keymap.set('', 'gh', '^', opts.nore) -- Go to first non-blank character

-- ----------------------------------------------------------------------------
-- Terminal Integration
-- ----------------------------------------------------------------------------

-- Prevent accidental terminal suspension
-- Map Ctrl-c to Esc to avoid breaking out of Neovim
-- Useful when running in terminal multiplexers like tmux
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
-- END OF KEYMAPS CONFIGURATION
-- ============================================================================
