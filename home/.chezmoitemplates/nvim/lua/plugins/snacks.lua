-- https://github.com/folke/snacks.nvim
-- Snacks.nvim is a collection of small QoL plugins for Neovim
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- ╭─────────────────────────────────────────────────────────╮
    -- │                     Picker Module                       │
    -- ╰─────────────────────────────────────────────────────────╯
    --- @doc: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-config
    --- @type snacks.picker.Config
    picker = {
      enabled = true,
      -- Replace vim.ui.select with snacks picker
      ui_select = true,

      -- Matcher configuration
      matcher = {
        frecency = true, -- enable frecency sorting (built-in, no extension needed)
        history_bonus = true, -- boost recently used items
      },

      -- Source-specific configurations
      sources = {
        --- @doc: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#files
        files = {
          hidden = true, -- show hidden/dot files
          exclude = { '.git' }, -- exclude .git directory
        },
        --- @doc: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#grep
        grep = {
          hidden = true, -- search in hidden files
          exclude = { '.git' }, -- exclude .git directory
        },
      },

      -- Icons (requires nerd font)
      icons = {
        files = {
          enabled = vim.g.have_nerd_font,
        },
      },
    },

    -- ╭─────────────────────────────────────────────────────────╮
    -- │                    Other Modules                        │
    -- ╰─────────────────────────────────────────────────────────╯
    -- Enable other useful snacks modules
    bigfile = { enabled = true },
    notifier = { enabled = false }, -- using nvim-notify via noice
    quickfile = { enabled = true },
    statuscolumn = { enabled = false }, -- using custom statuscolumn
  },

  -- ╭─────────────────────────────────────────────────────────╮
  -- │                       Keymaps                           │
  -- ╰─────────────────────────────────────────────────────────╯
  keys = {
    -- ── File/Buffer Pickers ──────────────────────────────────
    {
      '<leader><leader>',
      function()
        Snacks.picker.buffers()
      end,
      desc = '[ ] Find existing buffers',
    },
    {
      '<leader>sf',
      function()
        Snacks.picker.files()
      end,
      desc = '[S]earch [F]iles',
    },
    {
      '<leader>s.',
      function()
        Snacks.picker.recent()
      end,
      desc = '[S]earch Recent Files ("." for repeat)',
    },
    {
      '<leader>sn',
      function()
        Snacks.picker.files({ cwd = vim.fn.stdpath('config') })
      end,
      desc = '[S]earch [N]eovim files',
    },

    -- ── Grep/Search Pickers ──────────────────────────────────
    {
      '<leader>sg',
      function()
        Snacks.picker.grep()
      end,
      desc = '[S]earch by [G]rep',
    },
    {
      '<leader>sw',
      function()
        Snacks.picker.grep_word()
      end,
      desc = '[S]earch current [W]ord',
    },
    {
      '<leader>/',
      function()
        Snacks.picker.lines({ layout = 'dropdown' })
      end,
      desc = '[/] Fuzzily search in current buffer',
    },
    {
      '<leader>s/',
      function()
        Snacks.picker.grep_buffers()
      end,
      desc = '[S]earch [/] in Open Files',
    },

    -- ── Vim/Neovim Pickers ───────────────────────────────────
    {
      '<leader>sh',
      function()
        Snacks.picker.help()
      end,
      desc = '[S]earch [H]elp',
    },
    {
      '<leader>sk',
      function()
        Snacks.picker.keymaps()
      end,
      desc = '[S]earch [K]eymaps',
    },
    {
      '<leader>sc',
      function()
        Snacks.picker.colorschemes()
      end,
      desc = '[S]earch [C]olorscheme',
    },
    {
      '<leader>ss',
      function()
        Snacks.picker.pickers()
      end,
      desc = '[S]earch [S]elect Snacks pickers',
    },
    {
      '<leader>sd',
      function()
        Snacks.picker.diagnostics()
      end,
      desc = '[S]earch [D]iagnostics',
    },
    {
      '<leader>sr',
      function()
        Snacks.picker.resume()
      end,
      desc = '[S]earch [R]esume',
    },

    -- ── Git Pickers ──────────────────────────────────────────
    {
      '<leader>gb',
      function()
        Snacks.picker.git_branches()
      end,
      desc = '[G]it [B]ranches',
    },
    {
      '<leader>gl',
      function()
        Snacks.picker.git_log()
      end,
      desc = '[G]it [L]og',
    },
    {
      '<leader>gf',
      function()
        Snacks.picker.git_log_file()
      end,
      desc = '[G]it Log [F]ile',
    },
  },

  init = function()
    -- TODO: use terminal
    --
  end,
}
