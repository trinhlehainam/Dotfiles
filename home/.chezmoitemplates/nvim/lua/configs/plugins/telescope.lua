-- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#file-and-text-search-in-hidden-files-and-directories
-- See `:help telescope` and `:help telescope.setup()`
local telescope = require('telescope')
local telescopeConfig = require('telescope.config')

-- Clone the default Telescope configuration
local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }

-- I want to search in hidden/dot files.
table.insert(vimgrep_arguments, '--hidden')
-- I don't want to search in the `.git` directory.
table.insert(vimgrep_arguments, '--glob')
table.insert(vimgrep_arguments, '!**/.git/*')
require('telescope').setup({
  defaults = {
    -- `hidden = true` is not supported in text grep commands.
    vimgrep_arguments = vimgrep_arguments,
    mappings = {
      i = {
        ['<C-u>'] = false,
        ['<C-d>'] = false,
      },
    },
  },
  pickers = {
    find_files = {
      -- `hidden = true` will still show the inside of `.git/` as it's not `.gitignore`d.
      find_command = { 'rg', '--files', '--hidden', '--glob', '!**/.git/*' },
    },
    colorscheme = {
      enable_preview = true,
    },
  },
  extensions = {
    ['ui-select'] = {
      require('telescope.themes').get_dropdown(),
    },
  },
})

-- Enable telescope fzf native, if installed
pcall(telescope.load_extension, 'fzf')
pcall(telescope.load_extension, 'ui-select')

-- See `:help telescope.builtin`
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>sc', builtin.colorscheme, { desc = '[S]earch [C]olorscheme' })
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
vim.keymap.set(
  'n',
  '<leader>s.',
  builtin.oldfiles,
  { desc = '[S]earch Recent Files ("." for repeat)' }
)
vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

-- Slightly advanced example of overriding default behavior and theme
vim.keymap.set('n', '<leader>/', function()
  -- You can pass additional configuration to Telescope to change the theme, layout, etc.
  builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({
    winblend = 10,
    previewer = false,
  }))
end, { desc = '[/] Fuzzily search in current buffer' })

-- It's also possible to pass additional configuration options.
--  See `:help telescope.builtin.live_grep()` for information about particular keys
vim.keymap.set('n', '<leader>s/', function()
  builtin.live_grep({
    grep_open_files = true,
    prompt_title = 'Live Grep in Open Files',
  })
end, { desc = '[S]earch [/] in Open Files' })

-- Shortcut for searching your Neovim configuration files
vim.keymap.set('n', '<leader>sn', function()
  builtin.find_files({ cwd = vim.fn.stdpath('config') })
end, { desc = '[S]earch [N]eovim files' })
