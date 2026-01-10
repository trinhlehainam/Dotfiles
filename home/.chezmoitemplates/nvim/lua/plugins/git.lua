return {
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim', -- required
      'sindrets/diffview.nvim', -- optional - Diff integration
    },
    config = function()
      local neogit = require('neogit')

      --- @source https://github.com/NeogitOrg/neogit?tab=readme-ov-file#configuration
      neogit.setup({
        mappings = {
          -- Setting any of these to `false` will disable the mapping.
          popup = {},
          status = {},
        },
        -- `graph_style = 'kitty'` renders the commit graph using Kitty-style glyphs.
        -- This works best in kitty, but in other terminals you'll need a font that
        -- provides those symbols (e.g. https://github.com/rbong/flog-symbols).
        graph_style = 'kitty',
      })

      local diffview = require('diffview')
      diffview.setup()

      vim.keymap.set(
        'n',
        '<leader>gs',
        neogit.open,
        { desc = '[S]how [G]it', silent = true, noremap = true }
      )
      vim.keymap.set(
        'n',
        '<leader>gc',
        ':Neogit commit<CR>',
        { desc = '[G]it [C]ommit', silent = true, noremap = true }
      )
      vim.keymap.set(
        'n',
        '<leader>gp',
        ':Neogit pull<CR>',
        { desc = '[G]it [P]ull', silent = true, noremap = true }
      )
      vim.keymap.set(
        'n',
        '<leader>gP',
        ':Neogit push<CR>',
        { desc = '[G]it [P]ush', silent = true, noremap = true }
      )
    end,
  },
  -- 'tpope/vim-rhubarb',
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
    config = function(_, opts)
      require('gitsigns').setup(opts)

      -- Workaround: :Gitsigns blame uses scrollbind which can't account for visual
      -- offset lines (floating overlays, virtual text). Temporarily disable these
      -- plugins during blame.
      -- Refs: gitsigns#368, nvim-treesitter-context#579

      ---@class GitsignsBlameOffsetPlugin
      ---@field name string Module name for require()
      ---@field module table? Loaded module reference (nil until loaded)
      ---@field is_active fun(m: table): boolean Check if plugin is currently active
      ---@field disable fun(m: table) Disable the plugin
      ---@field enable fun(m: table) Re-enable the plugin
      ---@field was_active boolean State before blame opened

      ---@type GitsignsBlameOffsetPlugin[]
      local offset_plugins = {
        {
          name = 'treesitter-context',
          is_active = function(m)
            return m.enabled()
          end,
          disable = function(m)
            m.disable()
          end,
          enable = function(m)
            m.enable()
          end,
          was_active = false,
        },
        {
          name = 'lensline',
          is_active = function(m)
            return m.is_visible()
          end,
          disable = function(m)
            m.hide()
          end,
          enable = function(m)
            m.show()
          end,
          was_active = false,
        },
      }

      local loaded = {}
      for _, p in ipairs(offset_plugins) do
        local ok, module = pcall(require, p.name)
        if ok then
          p.module = module
          table.insert(loaded, p)
        end
      end
      if #loaded == 0 then
        return
      end

      local blame_count = 0
      local source_win = nil
      local source_buf = nil
      local source_win_aucmd = nil
      local source_buf_aucmd = nil
      local group = vim.api.nvim_create_augroup('GitsignsBlameVisualOffset', {})

      --- Restore plugins to their previous state
      local function restore_plugins()
        for _, p in ipairs(loaded) do
          if p.was_active then
            p.enable(p.module)
          end
        end
      end

      --- Clean up all source-related autocmds
      local function cleanup_source_aucmds()
        if source_win_aucmd then
          pcall(vim.api.nvim_del_autocmd, source_win_aucmd)
          source_win_aucmd = nil
        end
        if source_buf_aucmd then
          pcall(vim.api.nvim_del_autocmd, source_buf_aucmd)
          source_buf_aucmd = nil
        end
      end

      --- Handle source window/buffer closing before blame
      local function on_source_closed()
        if blame_count > 0 then
          restore_plugins()
          blame_count = 0
          source_win = nil
          source_buf = nil
          cleanup_source_aucmds()
        end
      end

      --- Run function in source window context (needed for buffer-local plugins like lensline)
      ---@param fn fun()
      local function in_source_win(fn)
        if source_win and vim.api.nvim_win_is_valid(source_win) then
          pcall(vim.api.nvim_win_call, source_win, fn)
        else
          fn()
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'gitsigns-blame',
        group = group,
        callback = function(ev)
          if blame_count == 0 then
            -- Capture source window and buffer (alternate window when blame split is created)
            source_win = vim.fn.win_getid(vim.fn.winnr('#'))
            source_buf = vim.api.nvim_win_get_buf(source_win)
            in_source_win(function()
              for _, p in ipairs(loaded) do
                p.was_active = p.is_active(p.module)
                if p.was_active then
                  p.disable(p.module)
                end
              end
            end)

            -- Watch for source window closing before blame
            source_win_aucmd = vim.api.nvim_create_autocmd('WinClosed', {
              pattern = tostring(source_win),
              group = group,
              once = true,
              callback = on_source_closed,
            })

            -- Watch for source buffer being deleted (e.g., :bd, :bw)
            source_buf_aucmd = vim.api.nvim_create_autocmd('BufUnload', {
              buffer = source_buf,
              group = group,
              once = true,
              callback = on_source_closed,
            })
          end
          blame_count = blame_count + 1

          vim.api.nvim_create_autocmd('BufWipeout', {
            buffer = ev.buf,
            group = group,
            once = true,
            callback = function()
              if blame_count <= 0 then
                return -- Already cleaned up by on_source_closed
              end
              blame_count = blame_count - 1
              if blame_count == 0 then
                in_source_win(restore_plugins)
                source_win = nil
                source_buf = nil
                cleanup_source_aucmds()
              end
            end,
          })
        end,
      })
    end,
  },
  -- https://github.com/pwntester/octo.nvim
  {
    'pwntester/octo.nvim',
    cmd = 'Octo',
    opts = {
      picker = 'snacks',
      -- bare Octo command opens picker of commands
      enable_builtin = true,
    },
    keys = {
      {
        '<leader>Oi',
        '<CMD>Octo issue list<CR>',
        desc = 'List GitHub Issues',
      },
      {
        '<leader>Op',
        '<CMD>Octo pr list<CR>',
        desc = 'List GitHub PullRequests',
      },
      {
        '<leader>Od',
        '<CMD>Octo discussion list<CR>',
        desc = 'List GitHub Discussions',
      },
      {
        '<leader>On',
        '<CMD>Octo notification list<CR>',
        desc = 'List GitHub Notifications',
      },
      {
        '<leader>Os',
        function()
          require('octo.utils').create_base_search_command({ include_current_repo = true })
        end,
        desc = 'Search GitHub',
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'folke/snacks.nvim',
      'nvim-tree/nvim-web-devicons',
    },
  },
}
