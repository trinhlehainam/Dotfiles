-- One-shot target line used by blame -> Diffview handoff.
---@type integer|nil
local pending_blame_diffview_lnum = nil
local lsp_codelens = require('utils.lsp_codelens')
-- Monotonic id for blame->Diffview jump requests.
-- Deferred cleanup only clears state when its captured id is still current.
---@type integer
local pending_blame_diffview_req_id = 0

return {
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim', -- required
      'sindrets/diffview.nvim', -- optional - Diff integration
    },
    config = function()
      local neogit = require('neogit')
      local project_options = require('configs.project.options')

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

      ---@class dotfiles.DiffviewMainFileLike
      ---@field bufnr integer
      ---@class dotfiles.DiffviewMainWinLike
      ---@field id integer
      ---@field file dotfiles.DiffviewMainFileLike
      ---@class dotfiles.DiffviewLayoutLike
      ---@field get_main_win fun(self: dotfiles.DiffviewLayoutLike): dotfiles.DiffviewMainWinLike
      ---@class dotfiles.DiffviewEmitterLike
      ---@field on fun(self: dotfiles.DiffviewEmitterLike, event: string, callback: fun(...))
      ---@class dotfiles.DiffviewViewLike
      ---@field cur_layout? dotfiles.DiffviewLayoutLike
      ---@field emitter? dotfiles.DiffviewEmitterLike

      -- Diffview virtual buffers may contain raw CP932 bytes from git.
      -- Convert only when the current main diff buffer is SJIS/CP932.
      ---@param fenc string?
      ---@return boolean
      local function is_sjis_fenc(fenc)
        fenc = (fenc or ''):lower()
        return fenc == 'cp932' or fenc == 'sjis' or fenc == 'shift_jis'
      end

      local ok_lib, diffview_lib = pcall(require, 'diffview.lib')

      -- Runtime layout instance for the active Diffview tab.
      ---@return dotfiles.DiffviewLayoutLike|nil
      local function current_layout()
        if not ok_lib then
          return nil
        end

        local view = diffview_lib.get_current_view()
        return view and view.cur_layout or nil
      end

      ---@param view? { cur_layout?: dotfiles.DiffviewLayoutLike }
      ---@return integer|nil
      local function current_main_bufnr(view)
        local layout = view and view.cur_layout or current_layout()
        if not layout then
          return nil
        end

        local ok_main, main_win = pcall(function()
          return layout:get_main_win()
        end)
        if not ok_main or not main_win then
          return nil
        end

        local main_buf = main_win.file and main_win.file.bufnr
        if not main_buf or not vim.api.nvim_buf_is_valid(main_buf) then
          return nil
        end

        return main_buf
      end

      ---@type integer|nil
      local diffview_codelens_bufnr = nil
      ---@type table<dotfiles.DiffviewViewLike, true>
      local diffview_codelens_views = setmetatable({}, { __mode = 'k' })

      local function clear_diffview_codelens()
        if not diffview_codelens_bufnr then
          return
        end

        lsp_codelens.clear_context(diffview_codelens_bufnr, 'diffview')
        diffview_codelens_bufnr = nil
      end

      ---@param view? { cur_layout?: dotfiles.DiffviewLayoutLike }
      local function sync_diffview_codelens(view)
        local main_buf = current_main_bufnr(view)
        if diffview_codelens_bufnr == main_buf then
          return
        end

        clear_diffview_codelens()
        if main_buf then
          lsp_codelens.set_context(main_buf, 'diffview', 'eol')
          diffview_codelens_bufnr = main_buf
        end
      end

      ---@param view? dotfiles.DiffviewViewLike
      local function attach_diffview_codelens_listener(view)
        if type(view) ~= 'table' or diffview_codelens_views[view] then
          return
        end

        local ok = pcall(function()
          view.emitter:on('file_open_post', function()
            sync_diffview_codelens(view)
          end)
        end)
        if not ok then
          return
        end

        diffview_codelens_views[view] = true
      end

      -- Diffview hooks also run for local file buffers; filter to virtual diffview buffers.
      ---@param bufnr integer
      ---@return boolean
      local function is_diffview_buf(bufnr)
        return vim.api.nvim_buf_is_valid(bufnr)
          and vim.api.nvim_buf_get_name(bufnr):match('^diffview://') ~= nil
      end

      -- Use main side encoding as the fast/explicit signal for cp932 conversion.
      ---@return boolean
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

      ---@param bufnr integer
      local function apply_diffview_project_settings(bufnr)
        if not ok_lib then
          return
        end

        local view = diffview_lib.get_current_view()
        -- `ctx.toplevel` is Diffview's resolved worktree root for the current
        -- repository. Use it instead of parsing the `diffview://` buffer name or
        -- `ctx.dir` so project-local settings follow the real repo root.
        local root = view and view.adapter and view.adapter.ctx and view.adapter.ctx.toplevel or nil
        if type(root) ~= 'string' or root == '' then
          return
        end

        project_options.apply_filetype_settings_for_root(bufnr, root)
      end

      -- force=true: trust SJIS signal from main buffer and decode directly.
      -- force=false: decode only when cp932->utf8->cp932 roundtrip matches raw bytes.
      ---@param raw string
      ---@param force boolean
      ---@return string|nil
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
      ---@param target_buf integer
      ---@param force boolean
      local function decode_buffer_once(target_buf, force)
        if vim.b[target_buf].sjis_decoded then
          return
        end

        local raw = table.concat(vim.api.nvim_buf_get_lines(target_buf, 0, -1, false), '\n')
        -- Empty buffers have nothing to decode; mark as handled to keep one-shot behavior.
        if raw == '' then
          vim.b[target_buf].sjis_decoded = true
          return
        end

        local converted = decode_cp932(raw, force)
        if not converted then
          return
        end

        local was_modifiable = vim.bo[target_buf].modifiable
        vim.bo[target_buf].modifiable = true
        vim.api.nvim_buf_set_lines(
          target_buf,
          0,
          -1,
          false,
          vim.split(converted, '\n', { plain = true })
        )
        vim.bo[target_buf].modifiable = was_modifiable
        vim.b[target_buf].sjis_decoded = true
      end

      -- One-shot post-open behavior for blame -> Diffview:
      -- close file panel (if open) and jump to the source line.
      ---@param bufnr integer
      local function apply_pending_blame_jump(bufnr)
        if not pending_blame_diffview_lnum then
          return
        end

        local layout = current_layout()
        if not layout then
          return
        end

        local ok_main, main_win = pcall(function()
          return layout:get_main_win()
        end)
        local main_buf = ok_main and main_win and main_win.file and main_win.file.bufnr or nil
        local target_win = ok_main and main_win and main_win.id or nil
        -- Run once when the main diff buffer becomes ready.
        if main_buf ~= bufnr or type(target_win) ~= 'number' then
          return
        end

        if ok_lib then
          local view = diffview_lib.get_current_view()
          if view and view.panel and view.panel.is_open and view.panel:is_open() then
            diffview.emit('toggle_files')
          end
        end

        local last = vim.api.nvim_buf_line_count(bufnr)
        local line = math.max(1, math.min(pending_blame_diffview_lnum, last))
        -- Delay cursor move until after panel toggling/layout settles.
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(target_win) then
            vim.api.nvim_win_set_cursor(target_win, { line, 0 })
          end
        end)
        pending_blame_diffview_lnum = nil
      end

      diffview.setup({
        hooks = {
          view_opened = function(view)
            attach_diffview_codelens_listener(view)
            sync_diffview_codelens(view)
          end,
          view_closed = function(view)
            if type(view) == 'table' then
              diffview_codelens_views[view] = nil
            end
            clear_diffview_codelens()
          end,
          view_enter = function(view)
            sync_diffview_codelens(view)
          end,
          view_leave = function()
            clear_diffview_codelens()
          end,
          diff_buf_read = function(bufnr, _)
            -- diff_buf_read also fires for local file buffers; only process
            -- Diffview virtual buffers here.
            if not is_diffview_buf(bufnr) then
              return
            end

            decode_buffer_once(bufnr, is_main_sjis())
            apply_diffview_project_settings(bufnr)
            apply_pending_blame_jump(bufnr)
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

      ---@class dotfiles.GitsignsBlameOffsetPlugin
      ---@field name string Module name for require()
      ---@field module table? Loaded module reference (nil until loaded)
      ---@field is_active fun(m: table): boolean Check if plugin is currently active
      ---@field disable fun(m: table) Disable the plugin
      ---@field enable fun(m: table) Re-enable the plugin
      ---@field was_active boolean State before blame opened

      ---@type dotfiles.GitsignsBlameOffsetPlugin[]
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

      --- Open Diffview for the blamed commit line under cursor.
      --- Uses gitsigns cache from the original source buffer.
      ---@param blame_buf integer gitsigns-blame buffer id
      ---@param blame_source_buf integer? source file buffer id
      local function open_diffview_from_blame(blame_buf, blame_source_buf)
        local ok_cache, gitsigns_cache = pcall(require, 'gitsigns.cache')
        if not ok_cache then
          return
        end

        -- Reuse blame data from the source buffer cache (same shape as gitsigns blame view).
        ---@type Gitsigns.CacheEntry|nil
        local bcache = blame_source_buf and gitsigns_cache.cache[blame_source_buf] or nil
        local blame = bcache and bcache.blame
        local entries = blame and blame.entries
        if type(entries) ~= 'table' then
          return
        end

        local blame_win = vim.fn.bufwinid(blame_buf)
        if blame_win == -1 then
          blame_win = vim.api.nvim_get_current_win()
        end
        -- Pick commit from the current line in the blame window.
        local lnum = vim.api.nvim_win_get_cursor(blame_win)[1]
        local info = entries[lnum]
        local sha = info and info.commit and info.commit.sha or nil
        if type(sha) ~= 'string' or not sha:match('^%x+$') then
          return
        end

        -- DiffviewOpen is used here so "d" jumps straight to the selected commit diff.
        -- Prefer file-scoped diff; fallback to commit-wide diff when path is unavailable.
        local relpath = info.filename or (bcache.git_obj and bcache.git_obj.relpath) or nil
        local open_cmd
        if type(relpath) == 'string' and relpath ~= '' then
          open_cmd = 'DiffviewOpen ' .. sha .. '^! -- ' .. vim.fn.fnameescape(relpath)
        else
          open_cmd = 'DiffviewOpen ' .. sha .. '^!'
        end

        -- Use commit-side line number when available (more stable for old commits).
        local target_lnum = (info.orig_lnum and info.orig_lnum > 0) and info.orig_lnum or lnum
        pending_blame_diffview_req_id = pending_blame_diffview_req_id + 1
        local req_id = pending_blame_diffview_req_id
        pending_blame_diffview_lnum = target_lnum
        local ok_open = pcall(vim.cmd, open_cmd)
        if not ok_open then
          if pending_blame_diffview_req_id == req_id then
            pending_blame_diffview_lnum = nil
          end
        else
          -- Safety net for edge cases where Diffview opens but our hook path
          -- never consumes pending_blame_diffview_lnum.
          -- local req_id capture timer id for this request only.
          -- If a newer request starts first, ids differ and this timer is ignored.
          vim.defer_fn(function()
            if pending_blame_diffview_req_id == req_id then
              pending_blame_diffview_lnum = nil
            end
          end, 3000)
        end
      end

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
        -- Multiple blame windows can exist; restore only when the session is active.
        if blame_count <= 0 then
          return
        end

        if source_buf and vim.api.nvim_buf_is_valid(source_buf) then
          lsp_codelens.clear_context(source_buf, 'gitsigns_blame')
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
            if vim.api.nvim_buf_is_valid(source_buf) then
              lsp_codelens.set_context(source_buf, 'gitsigns_blame', 'eol')
            end
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

          -- Override order for blame "d":
          -- 1) FileType callback runs
          -- 2) gitsigns applies its default blame maps
          -- 3) scheduled map runs last and overrides "d"
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(ev.buf) then
              return
            end

            local function open()
              open_diffview_from_blame(ev.buf, source_buf)
            end

            vim.keymap.set('n', 'd', open, {
              buffer = ev.buf,
              silent = true,
              noremap = true,
              desc = 'Diffview for blamed commit',
            })
          end)

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
