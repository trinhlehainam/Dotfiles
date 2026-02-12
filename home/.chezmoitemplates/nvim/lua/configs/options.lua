-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- Reduce "Press ENTER" prompts during startup
-- See: `:help hit-enter`
vim.o.cmdheight = 2

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Tabstop settings
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.softtabstop = 2
vim.o.expandtab = false
vim.o.smartindent = true
vim.o.smarttab = true

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Prefer UTF-8, but still detect Japanese legacy encodings when needed.
vim.opt.fileencodings = { 'ucs-bom', 'utf-8', 'cp932', 'sjis', 'default', 'latin1' }

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Custom settings

-- Disable break line when text go off editor's window
vim.o.wrap = false

-- Indicate limit number of character in oneline shouldn't be crossed
vim.o.colorcolumn = '80'

-- Enables project-local configuration
-- See https://neovim.io/doc/user/options.html#'exrc'
-- Since version 0.9.0 Neovim has built-in secure, see https://neovim.io/doc/user/lua.html#vim.secure
vim.o.exrc = true

vim.o.spelllang = 'en_us'
vim.o.spell = false

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

local utils = require('utils.common')
-- https://github.com/williamboman/mason.nvim/issues/1753
if utils.IS_WINDOWS and vim.fn.executable('pyenv') then
  local version = vim.fn.system('pyenv global'):gsub('\n', '')
  local user_profile = vim.fn.getenv('USERPROFILE')
  local python_path = user_profile .. '/.pyenv/pyenv-win/versions/' .. version
  if vim.fn.isdirectory(python_path) and vim.fn.executable(python_path .. '/python.exe') then
    local path = vim.fn.getenv('PATH')
    vim.fn.setenv('PATH', python_path .. ';' .. path)
  end
end
