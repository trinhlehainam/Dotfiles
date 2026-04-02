-- PHP LSP config (Intelephense)
-- Ref: https://github.com/bmewburn/intelephense-docs

local LanguageSetting = require('configs.lsp.base')
local LspConfig = require('configs.lsp.lspconfig')
local log = require('utils.log')
local lsp_codelens = require('utils.lsp_codelens')
local Methods = vim.lsp.protocol.Methods

local M = LanguageSetting:new()

-- Treesitter
M.treesitter.filetypes = { 'php' }

-- Formatters
M.formatterconfig.mason_packages = { 'blade-formatter', 'php-cs-fixer' }
M.formatterconfig.formatters_by_ft = {
  blade = { 'blade-formatter' },
  php = { 'php_cs_fixer' },
}

-- Linters
M.linterconfig.mason_packages = { 'phpstan', 'phpcs' }
M.linterconfig.linters_by_ft = { php = { 'phpstan', 'phpcs' } }
M.linterconfig.lint_on_save = false

-- Intelephense LSP
local intelephense = LspConfig:new('intelephense', 'intelephense')

-- Constants
local CACHE_PATH = vim.fn.stdpath('cache') .. '/intelephense'
local STOP_TIMEOUT = 5000
local POLL_INTERVAL = 50
local UNUSED_REFS_REFRESH_DELAY_MS = 100
local UNUSED_REFS_CACHE_TIMEOUT_MS = 800

local CMD = {
  INDEX = 'IntelephenseIndexWorkspace',
  CANCEL = 'IntelephenseCancelIndexing',
  STATUS = 'IntelephenseStatus',
}

---@class dotfiles.IntelephenseUnusedRefsState
---@field timer? uv.uv_timer_t
---@field refresh_seq? integer

-- State
local commands_registered = false
local indexing_in_progress = false
---@type table<integer, table<integer, true>>
local active_clients = {}
---@type table<integer, dotfiles.IntelephenseUnusedRefsState>
local unused_refs_states = {}
local unused_refs_augroup = vim.api.nvim_create_augroup('dotfiles-intelephense-unused-refs', { clear = true })

local function get_client()
  return vim.lsp.get_clients({ name = 'intelephense' })[1]
end

-- Register user commands
local function register_commands_once()
  if commands_registered then
    return
  end

  -- :IntelephenseIndexWorkspace - reindex (! = clear cache)
  vim.api.nvim_create_user_command(CMD.INDEX, function(opts)
    local clear_cache = opts.bang

    if not clear_cache and indexing_in_progress then
      log.info('Indexing in progress.', 'Intelephense')
      return
    end

    local client = get_client()
    if not client then
      log.warn('Intelephense is not running in this workspace.', 'Intelephense')
      return
    end

    local root_dir = client.config.root_dir
    -- Prefer a graceful shutdown here: forcing termination while the server is
    -- writing cache/index files risks corruption. The explicit false keeps this
    -- behavior independent of any future client exit_timeout setting.
    client:stop(false)

    local stopped = vim.wait(STOP_TIMEOUT, function()
      return client:is_stopped()
    end, POLL_INTERVAL)

    if not stopped then
      log.error('Could not stop Intelephense before reindexing.', 'Intelephense')
      return
    end

    -- Restart with resolved config, preserving handlers/on_attach
    local base_config = vim.lsp.config['intelephense'] or {}
    vim.lsp.start(vim.tbl_deep_extend('force', base_config, {
      root_dir = root_dir,
      init_options = {
        storagePath = CACHE_PATH,
        clearCache = clear_cache or nil,
      },
    }))

    if clear_cache then
      log.info('Full reindex requested (cache clear enabled).', 'Intelephense')
    else
      log.info('Incremental reindex requested.', 'Intelephense')
    end
  end, { bang = true, desc = 'Intelephense: Reindex (! clears cache)' })

  -- :IntelephenseStatus - show status
  vim.api.nvim_create_user_command(CMD.STATUS, function()
    local client = get_client()
    if not client then
      log.warn('Intelephense is not running in this workspace.', 'Intelephense')
      return
    end

    local status = indexing_in_progress and 'Indexing in progress' or 'Ready'
    log.info('Status: ' .. status .. ' | Cache: ' .. CACHE_PATH, 'Intelephense')
  end, { desc = 'Intelephense: Show status' })

  commands_registered = true
end

local function unregister_commands()
  vim.schedule(function()
    -- Defer to avoid calling nvim_del_user_command in a fast event context
    pcall(vim.api.nvim_del_user_command, CMD.INDEX)
    pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
    pcall(vim.api.nvim_del_user_command, CMD.STATUS)
  end)

  commands_registered = false
  indexing_in_progress = false
end

-- Indexing started handler
local function on_indexing_started()
  if indexing_in_progress then
    return
  end

  indexing_in_progress = true

  -- Register cancel command (only available during indexing)
  if vim.fn.exists(':' .. CMD.CANCEL) == 0 then
    vim.api.nvim_create_user_command(CMD.CANCEL, function()
      local client = get_client()
      if not client then
        log.warn('Intelephense is not running in this workspace.', 'Intelephense')
        return
      end

      client:request('cancelIndexing', {}, function(err)
        if err then
          log.error('Failed to cancel indexing: ' .. tostring(err), 'Intelephense')
        else
          indexing_in_progress = false
          pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
          log.info('Indexing canceled by user.', 'Intelephense')
        end
      end, 0)
    end, { desc = 'Intelephense: Cancel indexing' })
  end

  log.info('Indexing started.', 'Intelephense')
end

-- Indexing ended handler
local function on_indexing_ended()
  indexing_in_progress = false
  pcall(vim.api.nvim_del_user_command, CMD.CANCEL)
  log.info('Indexing finished.', 'Intelephense')
end

-- ============================================================================
-- Unused Function Diagnostics (via Intelephense CodeLens)
-- ============================================================================
local unused_refs_ns = vim.api.nvim_create_namespace('intelephense_unused_refs')

-- Extract symbol name from buffer at position
local function get_symbol_at(bufnr, line, col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)
  if not lines[1] then
    return nil
  end
  -- Extract word at column (handles $var, function names, class names)
  local text = lines[1]:sub(col + 1)
  return text:match('^%$?[%w_]+')
end

---@param bufnr integer
---@param lens lsp.CodeLens
---@param client vim.lsp.Client
---@return integer
local function lens_start_col(bufnr, lens, client)
  local ok, range = pcall(function()
    return vim.range.lsp(bufnr, lens.range, client.offset_encoding)
  end)
  if ok and range and type(range.start_col) == 'number' then
    return range.start_col
  end

  return lens.range.start.character
end

---@param bufnr integer
---@param client vim.lsp.Client
---@param lenses lsp.CodeLens[]?
local function set_unused_reference_diagnostics(bufnr, client, lenses)
  local client_id = client.id
  -- Lines with existing intelephense diagnostics
  local existing =
    vim.diagnostic.get(bufnr, { namespace = vim.lsp.diagnostic.get_namespace(client_id) })
  local diag_lines = vim.iter(existing):fold({}, function(acc, d)
    acc[d.lnum] = true
    return acc
  end)
  local has_existing = next(diag_lines) ~= nil

  -- Single pass: filter + map in one fold (3x fewer function calls)
  local diagnostics = vim.iter(lenses or {}):fold({}, function(acc, lens)
    local cmd = lens.command
    if cmd and cmd.title and cmd.title:match('^0 References') then
      local pos = lens.range.start
      if not has_existing or not diag_lines[pos.line] then
        local col = lens_start_col(bufnr, lens, client)
        local symbol = get_symbol_at(bufnr, pos.line, col) or 'symbol'
        acc[#acc + 1] = {
          lnum = pos.line,
          col = col,
          message = ("Symbol '%s' is declared but not used."):format(symbol),
          severity = vim.diagnostic.severity.HINT,
          source = 'intelephense',
          code = 'P1003',
        }
      end
    end
    return acc
  end)

  vim.diagnostic.set(unused_refs_ns, bufnr, diagnostics)
end

local function clear_unused_reference_diagnostics(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.diagnostic.set(unused_refs_ns, bufnr, {})
  end
end

---@param state dotfiles.IntelephenseUnusedRefsState
local function reset_unused_reference_refresh_timer(state)
  local timer = state.timer
  if not timer then
    return
  end

  state.timer = nil
  if timer:is_closing() then
    return
  end

  timer:stop()
  timer:close()
end

---@param bufnr integer
---@param state? dotfiles.IntelephenseUnusedRefsState
local function clear_unused_reference_state(bufnr, state)
  local current_state = unused_refs_states[bufnr]
  if not current_state or (state and current_state ~= state) then
    return
  end

  reset_unused_reference_refresh_timer(current_state)
  unused_refs_states[bufnr] = nil
end

---@param bufnr integer
---@param state dotfiles.IntelephenseUnusedRefsState
---@param seq integer
---@return boolean
local function is_unused_reference_refresh_current(bufnr, state, seq)
  return vim.api.nvim_buf_is_valid(bufnr)
    and unused_refs_states[bufnr] == state
    and state.refresh_seq == seq
end

---@param bufnr integer
---@param client_id integer
---@return lsp.CodeLens[]
local function get_cached_codelenses(bufnr, client_id)
  local results
  if lsp_codelens.is_active(bufnr) then
    results = lsp_codelens.get({ bufnr = bufnr, client_id = client_id })
  else
    results = vim.lsp.codelens.get({ bufnr = bufnr, client_id = client_id })
  end

  local lenses = {}
  for _, item in ipairs(results) do
    local lens = item.lens or item
    lenses[#lenses + 1] = lens
  end

  return lenses
end

---@param lenses lsp.CodeLens[]
---@return string
local function codelens_cache_key(lenses)
  local parts = {}

  for _, lens in ipairs(lenses) do
    local range = lens.range or {}
    local start_pos = range.start or {}
    local end_pos = range['end'] or {}
    local title = lens.command and lens.command.title or ''
    parts[#parts + 1] = table.concat({
      tostring(start_pos.line or -1),
      tostring(start_pos.character or -1),
      tostring(end_pos.line or -1),
      tostring(end_pos.character or -1),
      title,
    }, ':')
  end

  table.sort(parts)
  return table.concat(parts, '|')
end

---@param client_id integer
---@return table<integer, true>?
local function prune_active_client_buffers(client_id)
  local bufnrs = active_clients[client_id]
  if not bufnrs then
    return nil
  end

  for bufnr in pairs(bufnrs) do
    if not vim.api.nvim_buf_is_valid(bufnr) then
      bufnrs[bufnr] = nil
    end
  end

  if next(bufnrs) == nil then
    active_clients[client_id] = nil
    return nil
  end

  active_clients[client_id] = bufnrs
  return bufnrs
end

---@param client_id integer
---@param bufnr integer
local function track_active_client_buffer(client_id, bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local bufnrs = prune_active_client_buffers(client_id) or {}
  bufnrs[bufnr] = true
  active_clients[client_id] = bufnrs
end

---@param client_id integer
---@param bufnr integer
local function untrack_active_client_buffer(client_id, bufnr)
  local bufnrs = prune_active_client_buffers(client_id)
  if not bufnrs then
    return
  end

  bufnrs[bufnr] = nil
  if next(bufnrs) == nil then
    active_clients[client_id] = nil
    return
  end

  active_clients[client_id] = bufnrs
end

---@param bufnr integer
local function untrack_buffer_from_all_active_clients(bufnr)
  for client_id in pairs(active_clients) do
    untrack_active_client_buffer(client_id, bufnr)
  end
end

---@param bufnr integer
---@return boolean
local has_active_client_in_buffer

---@param bufnr integer
---@param client vim.lsp.Client
---@param state dotfiles.IntelephenseUnusedRefsState
---@param seq integer
---@param lenses lsp.CodeLens[]?
---@param on_done fun(resolved_lenses: lsp.CodeLens[])
local function resolve_unused_reference_lenses(bufnr, client, state, seq, lenses, on_done)
  local resolved_lenses = vim.deepcopy(lenses or {})
  if not client:supports_method(Methods.codeLens_resolve, bufnr) then
    on_done(resolved_lenses)
    return
  end

  local pending = 0
  local finished = false
  local function finish()
    if finished then
      return
    end

    finished = true
    on_done(resolved_lenses)
  end

  for index, lens in ipairs(resolved_lenses) do
    if not lens.command then
      pending = pending + 1
      local ok = client:request(Methods.codeLens_resolve, lens, function(err, resolved_lens)
        if finished or not is_unused_reference_refresh_current(bufnr, state, seq) then
          return
        end

        pending = pending - 1
        if not err and resolved_lens then
          resolved_lenses[index] = resolved_lens
        end

        if pending == 0 then
          finish()
        end
      end, bufnr)

      if not ok then
        pending = pending - 1
        if pending == 0 then
          finish()
        end
      end
    end
  end

  if pending == 0 then
    finish()
  end
end

---@param bufnr integer
---@param client vim.lsp.Client
---@param state dotfiles.IntelephenseUnusedRefsState
---@param seq integer
---@param lenses lsp.CodeLens[]?
local function apply_unused_reference_diagnostics(bufnr, client, state, seq, lenses)
  resolve_unused_reference_lenses(bufnr, client, state, seq, lenses, function(resolved_lenses)
    if not is_unused_reference_refresh_current(bufnr, state, seq) then
      return
    end

    set_unused_reference_diagnostics(bufnr, client, resolved_lenses)
  end)
end

---@param bufnr integer
---@param client vim.lsp.Client
---@param state dotfiles.IntelephenseUnusedRefsState
---@param seq integer
local function request_unused_reference_diagnostics(bufnr, client, state, seq)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  client:request(Methods.textDocument_codeLens, params, function(err, lenses)
    if not is_unused_reference_refresh_current(bufnr, state, seq) then
      return
    end

    state.timer = nil
    if err then
      clear_unused_reference_diagnostics(bufnr)
      return
    end

    apply_unused_reference_diagnostics(bufnr, client, state, seq, lenses)
  end, bufnr)
end

---@param bufnr integer
---@param state dotfiles.IntelephenseUnusedRefsState
---@param seq integer
---@param initial_cache_key string
---@param remaining_ms integer
local function refresh_unused_reference_diagnostics_from_cache(bufnr, state, seq, initial_cache_key, remaining_ms)
  if not is_unused_reference_refresh_current(bufnr, state, seq) then
    return
  end

  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'intelephense' })[1]
  if not client or not client:supports_method(Methods.textDocument_codeLens, bufnr) then
    state.timer = nil
    clear_unused_reference_diagnostics(bufnr)
    return
  end

  local lenses = get_cached_codelenses(bufnr, client.id)
  local cache_key = codelens_cache_key(lenses)
  if cache_key ~= initial_cache_key then
    state.timer = nil
    apply_unused_reference_diagnostics(bufnr, client, state, seq, lenses)
    return
  end

  if remaining_ms <= 0 then
    state.timer = nil
    -- Cache keys can legitimately stay identical across refreshes, so use one
    -- direct request here instead of treating "unchanged cache" as "stale data".
    request_unused_reference_diagnostics(bufnr, client, state, seq)
    return
  end

  state.timer = vim.defer_fn(function()
    refresh_unused_reference_diagnostics_from_cache(
      bufnr,
      state,
      seq,
      initial_cache_key,
      remaining_ms - POLL_INTERVAL
    )
  end, POLL_INTERVAL)
end

---@param bufnr integer
---@param state dotfiles.IntelephenseUnusedRefsState
local function schedule_unused_reference_refresh(bufnr, state)
  if not vim.api.nvim_buf_is_valid(bufnr) or unused_refs_states[bufnr] ~= state then
    return
  end

  reset_unused_reference_refresh_timer(state)
  state.refresh_seq = (state.refresh_seq or 0) + 1
  local seq = state.refresh_seq
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'intelephense' })[1]
  local initial_cache_key = client and codelens_cache_key(get_cached_codelenses(bufnr, client.id)) or ''
  state.timer = vim.defer_fn(function()
    refresh_unused_reference_diagnostics_from_cache(
      bufnr,
      state,
      seq,
      initial_cache_key,
      UNUSED_REFS_CACHE_TIMEOUT_MS
    )
  end, UNUSED_REFS_REFRESH_DELAY_MS)
end

local function attach_unused_reference_updates_once(bufnr)
  if unused_refs_states[bufnr] then
    return
  end

  local state = {}
  unused_refs_states[bufnr] = state
  pcall(vim.api.nvim_clear_autocmds, { group = unused_refs_augroup, buffer = bufnr })
  vim.api.nvim_create_autocmd('LspDetach', {
    group = unused_refs_augroup,
    buffer = bufnr,
    callback = function(args)
      local client_id = args.data and args.data.client_id
      if not client_id then
        return
      end

      local client = vim.lsp.get_client_by_id(client_id)
      if client and client.name ~= 'intelephense' then
        return
      end

      untrack_active_client_buffer(client_id, args.buf)
      if not has_active_client_in_buffer(args.buf) then
        clear_unused_reference_state(args.buf)
        clear_unused_reference_diagnostics(args.buf)
      end

      if next(active_clients) == nil then
        unregister_commands()
      end
    end,
  })
  local attached = vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf)
      if unused_refs_states[buf] ~= state then
        return true
      end

      schedule_unused_reference_refresh(buf, state)
    end,
    on_reload = function(_, buf)
      if unused_refs_states[buf] ~= state then
        return true
      end

      schedule_unused_reference_refresh(buf, state)
    end,
    on_detach = function(_, buf)
      untrack_buffer_from_all_active_clients(buf)
      pcall(vim.api.nvim_clear_autocmds, { group = unused_refs_augroup, buffer = buf })
      clear_unused_reference_state(buf, state)
    end,
  })

  if not attached and unused_refs_states[bufnr] == state then
    unused_refs_states[bufnr] = nil
  end
end

has_active_client_in_buffer = function(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    untrack_buffer_from_all_active_clients(bufnr)
    return false
  end

  for client_id in pairs(active_clients) do
    local active_bufnrs = prune_active_client_buffers(client_id)
    if active_bufnrs and active_bufnrs[bufnr] then
      return true
    end
  end

  return false
end

intelephense.config = {
  init_options = { storagePath = CACHE_PATH },

  settings = {
    intelephense = {
      codeLens = {
        references = { enable = true },
        implementations = { enable = true },
        usages = { enable = true },
        overrides = { enable = true },
        parent = { enable = true },
      },
    },
  },

  -- Intelephense indexing notification handlers
  handlers = {
    ['indexingStarted'] = on_indexing_started,
    ['indexingEnded'] = on_indexing_ended,
  },

  on_attach = function(client, bufnr)
    track_active_client_buffer(client.id, bufnr)
    if client:supports_method(Methods.textDocument_codeLens, bufnr) then
      attach_unused_reference_updates_once(bufnr)
      local state = unused_refs_states[bufnr]
      if state then
        schedule_unused_reference_refresh(bufnr, state)
      end
    end
    register_commands_once()
  end,

  -- LSP on_exit may run in a fast event; schedule all editor-state cleanup.
  on_exit = vim.schedule_wrap(function(_, _, client_id)
    local bufnrs = prune_active_client_buffers(client_id) or {}
    active_clients[client_id] = nil

    for bufnr in pairs(bufnrs) do
      if not has_active_client_in_buffer(bufnr) then
        clear_unused_reference_state(bufnr)
        if vim.api.nvim_buf_is_valid(bufnr) then
          clear_unused_reference_diagnostics(bufnr)
        end
      end
    end

    if next(active_clients) == nil then
      unregister_commands()
    end
  end),
}

M.lspconfigs = { intelephense }

-- DAP
M.dapconfigs = {
  { type = 'php', use_masondap_default_setup = true },
}

-- Neotest
M.neotest_adapter_setup = function()
  local ok, adapter = pcall(require, 'neotest-phpunit')
  return ok and adapter or nil
end

return M
