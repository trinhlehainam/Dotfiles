local api = vim.api
local Methods = vim.lsp.protocol.Methods

local M = {}

local namespace = api.nvim_create_namespace('dotfiles.lsp.codelens')
local augroup = api.nvim_create_augroup('dotfiles-lsp-codelens', { clear = false })
local refresh_delay_ms = 200

---@class dotfiles.LspCodeLensEntry
---@field col integer
---@field title string

---@class dotfiles.LspCodeLensState
---@field clients table<integer, true>
---@field client_rows table<integer, table<integer, dotfiles.LspCodeLensEntry[]>>
---@field refresh_seq integer
---@field timer? uv.uv_timer_t

---@type table<integer, dotfiles.LspCodeLensState>
local states = {}

---@param state dotfiles.LspCodeLensState
local function reset_timer(state)
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
local function clear_extmarks(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

---@param bufnr integer
---@return dotfiles.LspCodeLensState?
local function get_state(bufnr)
  local state = states[bufnr]
  if not state then
    return nil
  end

  if api.nvim_buf_is_valid(bufnr) then
    return state
  end

  reset_timer(state)
  states[bufnr] = nil
  return nil
end

---@param bufnr integer
---@return dotfiles.LspCodeLensState
local function ensure_state(bufnr)
  local state = get_state(bufnr)
  if state then
    return state
  end

  state = {
    clients = {},
    client_rows = {},
    refresh_seq = 0,
  }
  states[bufnr] = state

  api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    group = augroup,
    callback = function(args)
      M.detach_all(args.buf)
    end,
  })

  api.nvim_create_autocmd('InsertEnter', {
    buffer = bufnr,
    group = augroup,
    callback = function(args)
      M.clear(args.buf)
    end,
  })

  api.nvim_create_autocmd('TextChanged', {
    buffer = bufnr,
    group = augroup,
    callback = function(args)
      M.clear(args.buf)
      M.schedule_refresh(args.buf)
    end,
  })

  api.nvim_create_autocmd('TextChangedI', {
    buffer = bufnr,
    group = augroup,
    callback = function(args)
      M.clear(args.buf)
    end,
  })

  api.nvim_create_autocmd({ 'InsertLeave', 'BufWritePost' }, {
    buffer = bufnr,
    group = augroup,
    callback = function(args)
      M.refresh(args.buf)
    end,
  })

  return state
end

---@param state dotfiles.LspCodeLensState
---@param seq integer
---@param tick integer
---@return boolean
local function is_refresh_current(bufnr, state, seq, tick)
  return states[bufnr] == state
    and state.refresh_seq == seq
    and api.nvim_buf_is_valid(bufnr)
    and api.nvim_buf_get_changedtick(bufnr) == tick
end

---@param rows table<integer, dotfiles.LspCodeLensEntry[]>
---@param lens lsp.CodeLens?
local function add_entry(rows, lens)
  if not lens or not lens.command or type(lens.command.title) ~= 'string' then
    return
  end

  local title = vim.trim(lens.command.title)
  if title == '' then
    return
  end

  local line = lens.range.start.line
  local entries = rows[line] or {}
  entries[#entries + 1] = {
    col = lens.range.start.character,
    title = title,
  }
  rows[line] = entries
end

---@param bufnr integer
---@param client_rows table<integer, table<integer, dotfiles.LspCodeLensEntry[]>>
local function render(bufnr, client_rows)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  clear_extmarks(bufnr)

  ---@type table<integer, dotfiles.LspCodeLensEntry[]>
  local merged_rows = {}
  for _, rows in pairs(client_rows) do
    for line, entries in pairs(rows) do
      local merged = merged_rows[line] or {}
      vim.list_extend(merged, entries)
      merged_rows[line] = merged
    end
  end

  for line, entries in pairs(merged_rows) do
    table.sort(entries, function(a, b)
      if a.col == b.col then
        return a.title < b.title
      end

      return a.col < b.col
    end)

    ---@type [string, string][]
    local virt_text = { { '  ', 'LspCodeLensSeparator' } }
    for index, entry in ipairs(entries) do
      virt_text[#virt_text + 1] = { entry.title, 'LspCodeLens' }
      if index < #entries then
        virt_text[#virt_text + 1] = { ' | ', 'LspCodeLensSeparator' }
      end
    end

    api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
      virt_text = virt_text,
      virt_text_pos = 'eol',
      hl_mode = 'combine',
    })
  end
end

---@param client vim.lsp.Client
---@param bufnr integer
---@param state dotfiles.LspCodeLensState
---@param seq integer
---@param tick integer
---@param lenses lsp.CodeLens[]?
---@param done fun(rows: table<integer, dotfiles.LspCodeLensEntry[]>)
local function resolve_rows(client, bufnr, state, seq, tick, lenses, done)
  ---@type table<integer, dotfiles.LspCodeLensEntry[]>
  local rows = {}
  local pending = 1
  local can_resolve = client:supports_method(Methods.codeLens_resolve, bufnr)

  local function finish()
    pending = pending - 1
    if pending == 0 then
      done(rows)
    end
  end

  for _, lens in ipairs(lenses or {}) do
    if lens.command then
      add_entry(rows, lens)
    elseif can_resolve then
      pending = pending + 1
      client:request(Methods.codeLens_resolve, lens, function(err, resolved_lens)
        if not err and is_refresh_current(bufnr, state, seq, tick) then
          add_entry(rows, resolved_lens)
        end
        finish()
      end, bufnr)
    end
  end

  finish()
end

---@param bufnr integer
local function refresh_now(bufnr)
  local state = get_state(bufnr)
  if not state then
    return
  end

  reset_timer(state)
  state.refresh_seq = state.refresh_seq + 1
  state.client_rows = {}

  local seq = state.refresh_seq
  local tick = api.nvim_buf_get_changedtick(bufnr)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local requested = false

  for client_id in pairs(state.clients) do
    local client = vim.lsp.get_client_by_id(client_id)
    if client and client:supports_method(Methods.textDocument_codeLens, bufnr) then
      requested = true
      client:request(Methods.textDocument_codeLens, params, function(err, result)
        if not is_refresh_current(bufnr, state, seq, tick) then
          return
        end

        if err then
          state.client_rows[client_id] = {}
          render(bufnr, state.client_rows)
          return
        end

        resolve_rows(client, bufnr, state, seq, tick, result, function(rows)
          if not is_refresh_current(bufnr, state, seq, tick) then
            return
          end

          state.client_rows[client_id] = rows
          render(bufnr, state.client_rows)
        end)
      end, bufnr)
    end
  end

  if not requested then
    clear_extmarks(bufnr)
  end
end

---@param bufnr integer
function M.clear(bufnr)
  local state = get_state(bufnr)
  if not state then
    return
  end

  reset_timer(state)
  state.refresh_seq = state.refresh_seq + 1
  state.client_rows = {}
  clear_extmarks(bufnr)
end

---@param bufnr integer
function M.schedule_refresh(bufnr)
  local state = get_state(bufnr)
  if not state then
    return
  end

  reset_timer(state)
  state.timer = vim.defer_fn(function()
    refresh_now(bufnr)
  end, refresh_delay_ms)
end

---@param bufnr integer
function M.refresh(bufnr)
  refresh_now(bufnr)
end

---@param client vim.lsp.Client
---@param bufnr integer
function M.attach(client, bufnr)
  if not client or not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local state = ensure_state(bufnr)
  state.clients[client.id] = true
  refresh_now(bufnr)
end

---@param bufnr integer
---@param client_id integer
function M.detach(bufnr, client_id)
  local state = get_state(bufnr)
  if not state or not state.clients[client_id] then
    return
  end

  state.clients[client_id] = nil
  state.client_rows[client_id] = nil

  if next(state.clients) == nil then
    M.detach_all(bufnr)
    return
  end

  M.clear(bufnr)
  refresh_now(bufnr)
end

---@param bufnr integer
function M.detach_all(bufnr)
  local state = get_state(bufnr)
  if not state then
    clear_extmarks(bufnr)
    return
  end

  reset_timer(state)
  states[bufnr] = nil
  clear_extmarks(bufnr)
  pcall(api.nvim_clear_autocmds, { group = augroup, buffer = bufnr })
end

return M
