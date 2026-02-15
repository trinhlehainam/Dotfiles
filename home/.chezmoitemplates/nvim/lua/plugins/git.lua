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

      -- Diffview virtual buffers may contain raw CP932 bytes from git.
      -- Convert only when the current main diff buffer is SJIS/CP932.
      local function is_sjis_fenc(fenc)
        fenc = (fenc or ''):lower()
        return fenc == 'cp932' or fenc == 'sjis' or fenc == 'shift_jis'
      end

      local ok_lib, diffview_lib = pcall(require, 'diffview.lib')

      -- Runtime layout instance for the active Diffview tab.
      local function current_layout()
        if not ok_lib then
          return nil
        end

        local view = diffview_lib.get_current_view()
        return view and view.cur_layout or nil
      end

      local function is_diffview_buf(bufnr)
        return vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr):match('^diffview://') ~= nil
      end

      -- Use main side encoding as the fast/explicit signal for cp932 conversion.
      local function is_main_sjis()
        local layout = current_layout()
        if not layout then
          return false
        end

        local ok_main, main_win = pcall(function()
          return layout:get_main_win()
        end)
        if not ok_main or not main_win then
          return false
        end

        local main_buf = main_win.file and main_win.file.bufnr
        if not main_buf or not vim.api.nvim_buf_is_valid(main_buf) then
          return false
        end

        return is_sjis_fenc(vim.bo[main_buf].fileencoding)
      end

      -- Collect unique Diffview virtual buffers from the current layout.
      -- Fallback to the event buffer if layout is temporarily unavailable.
      local function layout_diffview_buffers(fallback_bufnr)
        local layout = current_layout()
        if not layout or type(layout.windows) ~= 'table' then
          return { fallback_bufnr }
        end

        local seen = {}
        local bufs = {}
        for _, win in ipairs(layout.windows) do
          local target_buf = win and win.file and win.file.bufnr or nil
          if target_buf and not seen[target_buf] and is_diffview_buf(target_buf) then
            seen[target_buf] = true
            table.insert(bufs, target_buf)
          end
        end

        if #bufs == 0 then
          return { fallback_bufnr }
        end
        return bufs
      end

      local function decode_cp932(raw, force)
        local ok_decode, converted = pcall(vim.iconv, raw, 'cp932', 'utf-8')
        if not ok_decode or not converted or converted == '' then
          return nil
        end

        if force then
          return converted
        end

        -- Commit readonly buffers may not expose encoding metadata.
        -- Decode only when cp932<->utf8 roundtrip preserves original bytes.
        local ok_roundtrip, roundtrip = pcall(vim.iconv, converted, 'utf-8', 'cp932')
        if not ok_roundtrip or roundtrip ~= raw then
          return nil
        end

        return converted
      end

      -- Per-buffer one-shot conversion guard (important for diff3/diff4).
      local function decode_buffer_once(target_buf, force)
        if vim.b[target_buf].sjis_decoded then
          return
        end

        local raw = table.concat(vim.api.nvim_buf_get_lines(target_buf, 0, -1, false), '\n')
        local converted = decode_cp932(raw, force)
        if not converted then
          return
        end

        local was_modifiable = vim.bo[target_buf].modifiable
        vim.bo[target_buf].modifiable = true
        vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, vim.split(converted, '\n', { plain = true }))
        vim.bo[target_buf].modifiable = was_modifiable
        vim.b[target_buf].sjis_decoded = true
      end

      diffview.setup({
        hooks = {
          diff_buf_read = function(bufnr, _)
            if not is_diffview_buf(bufnr) then
              return
            end

            -- Convert all panes in the current layout in one pass.
            local force = is_main_sjis()
            for _, target_buf in ipairs(layout_diffview_buffers(bufnr)) do
              decode_buffer_once(target_buf, force)
            end
          end,
        },
      })

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
      local source_hidden_aucmd = nil
      local blame_win_aucmd = nil
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
        if source_hidden_aucmd then
          pcall(vim.api.nvim_del_autocmd, source_hidden_aucmd)
          source_hidden_aucmd = nil
        end
        if blame_win_aucmd then
          pcall(vim.api.nvim_del_autocmd, blame_win_aucmd)
          blame_win_aucmd = nil
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

      --- Restore offset plugins and clear all state.
      ---
      --- We restore in the source window context when possible because some plugins
      --- refresh based on the current window/buffer.
      local function restore_and_reset()
        if blame_count <= 0 then
          return
        end

        in_source_win(restore_plugins)
        blame_count = 0
        source_win = nil
        source_buf = nil
        cleanup_source_aucmds()
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

            -- Source window/buffer going away ends the blame session.
            -- NOTE: WinClosed matches on the window id via the autocmd {pattern}.
            source_win_aucmd = vim.api.nvim_create_autocmd('WinClosed', {
              pattern = tostring(source_win),
              group = group,
              once = true,
              callback = restore_and_reset,
            })

            -- Gitsigns closes blame when the *source buffer* becomes hidden.
            source_hidden_aucmd = vim.api.nvim_create_autocmd('BufHidden', {
              buffer = source_buf,
              group = group,
              once = true,
              callback = restore_and_reset,
            })
          end
          blame_count = blame_count + 1

          -- Explicitly closing the blame split doesn't necessarily hide the source buffer.
          -- Catch that path too.
          -- NOTE: WinClosed matches on the window id via the autocmd {pattern}.
          local blame_win = vim.fn.bufwinid(ev.buf)
          if blame_win == -1 then
            blame_win = vim.api.nvim_get_current_win()
          end

          blame_win_aucmd = vim.api.nvim_create_autocmd('WinClosed', {
            pattern = tostring(blame_win),
            group = group,
            once = true,
            callback = restore_and_reset,
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
