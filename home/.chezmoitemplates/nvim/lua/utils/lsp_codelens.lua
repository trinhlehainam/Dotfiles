local api = vim.api
local Methods = vim.lsp.protocol.Methods

local M = {}

local namespace = api.nvim_create_namespace('dotfiles.lsp.codelens')
local augroup = api.nvim_create_augroup('dotfiles-lsp-codelens', { clear = false })
local refresh_delay_ms = 200

---@class dotfiles.LspCodeLensState
---@field contexts table<string, 'eol'>
---@field client_rows table<integer, table<integer, lsp.CodeLens[]>>
---@field refresh_seq integer
---@field timer? uv.uv_timer_t
---@field render_scheduled? boolean

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

---@param lens lsp.CodeLens
---@return string?
local function lens_title(lens)
  if not lens.command or type(lens.command.title) ~= 'string' then
    return nil
  end

  local title = vim.trim(lens.command.title)
  return title ~= '' and title or nil
end

---@param bufnr integer
---@param lens lsp.CodeLens
---@param client vim.lsp.Client
---@return integer
local function lens_col(bufnr, lens, client)
  local ok, range = pcall(vim.range.lsp, bufnr, lens.range, client.offset_encoding)
  if ok and range and type(range.start_col) == 'number' then
    return range.start_col
  end

  return lens.range.start.character
end

---@param state dotfiles.LspCodeLensState
---@return boolean
local function has_contexts(state)
  return next(state.contexts) ~= nil
end

---@param bufnr integer
---@return dotfiles.LspCodeLensState
local function ensure_state(bufnr)
  local state = get_state(bufnr)
  if state then
    return state
  end

  state = {
    contexts = {},
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

---@param bufnr integer
---@param state dotfiles.LspCodeLensState
---@param seq integer
---@param tick integer
---@return boolean
local function is_refresh_current(bufnr, state, seq, tick)
  return states[bufnr] == state
    and has_contexts(state)
    and state.refresh_seq == seq
    and api.nvim_buf_is_valid(bufnr)
    and api.nvim_buf_get_changedtick(bufnr) == tick
end

---@param bufnr integer
---@param state dotfiles.LspCodeLensState
local render

---@param bufnr integer
---@param state dotfiles.LspCodeLensState
local function schedule_render(bufnr, state)
  if state.render_scheduled then
    return
  end

  state.render_scheduled = true
  vim.schedule(function()
    if states[bufnr] ~= state then
      return
    end

    state.render_scheduled = nil
    render(bufnr, state)
  end)
end

---@param bufnr integer
---@param state dotfiles.LspCodeLensState
render = function(bufnr, state)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  clear_extmarks(bufnr)

  local line_count = api.nvim_buf_line_count(bufnr)
  local merged_rows = {}
  for client_id, rows in pairs(state.client_rows) do
    local client = vim.lsp.get_client_by_id(client_id)
    if client then
      for line, lenses in pairs(rows) do
        local items = merged_rows[line] or {}
        for _, lens in ipairs(lenses) do
          local title = lens_title(lens)
          if title then
            items[#items + 1] = {
              col = lens_col(bufnr, lens, client),
              title = title,
            }
          end
        end
        merged_rows[line] = items
      end
    end
  end

  for line, items in pairs(merged_rows) do
    if type(line) ~= 'number' or line < 0 or line >= line_count then
      goto continue
    end

    table.sort(items, function(a, b)
      if a.col == b.col then
        return a.title < b.title
      end

      return a.col < b.col
    end)

    if #items > 0 then
      ---@type [string, string][]
      local virt_text = { { '  ', 'LspCodeLensSeparator' } }

      for index, item in ipairs(items) do
        virt_text[#virt_text + 1] = { item.title, 'LspCodeLens' }
        if index < #items then
          virt_text[#virt_text + 1] = { ' | ', 'LspCodeLensSeparator' }
        end
      end

      api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
        virt_text = virt_text,
        virt_text_pos = 'eol',
        hl_mode = 'combine',
      })
    end

    ::continue::
  end
end

---@param lenses lsp.CodeLens[]?
---@return table<integer, lsp.CodeLens[]>
local function group_lenses(lenses)
  local rows = {}

  for _, lens in ipairs(lenses or {}) do
    local line = lens.range.start.line
    local row_lenses = rows[line] or {}
    row_lenses[#row_lenses + 1] = lens
    rows[line] = row_lenses
  end

  return rows
end

---@param client vim.lsp.Client
---@param bufnr integer
---@param state dotfiles.LspCodeLensState
---@param seq integer
---@param tick integer
---@param unresolved_lens lsp.CodeLens
local function resolve_lens(client, bufnr, state, seq, tick, unresolved_lens)
  client:request(Methods.codeLens_resolve, unresolved_lens, function(err, resolved_lens)
    if err or not resolved_lens or not is_refresh_current(bufnr, state, seq, tick) then
      return
    end

    local client_rows = state.client_rows[client.id]
    if not client_rows then
      return
    end

    local row = unresolved_lens.range.start.line
    local row_lenses = client_rows[row]
    if not row_lenses then
      return
    end

    for index, lens in ipairs(row_lenses) do
      if lens == unresolved_lens then
        row_lenses[index] = resolved_lens
        schedule_render(bufnr, state)
        return
      end
    end
  end, bufnr)
end

---@param bufnr integer
local function refresh_now(bufnr)
  local state = get_state(bufnr)
  if not state then
    return
  end

  -- Mirror Neovim's built-in CodeLens request/resolve lifecycle, but keep
  -- rendering local so git-driven contexts can place titles at end-of-line.
  reset_timer(state)
  state.refresh_seq = state.refresh_seq + 1
  state.client_rows = {}

  local seq = state.refresh_seq
  local tick = api.nvim_buf_get_changedtick(bufnr)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local requested = false

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method(Methods.textDocument_codeLens, bufnr) then
      requested = true
      client:request(Methods.textDocument_codeLens, params, function(err, result)
        if not is_refresh_current(bufnr, state, seq, tick) then
          return
        end

        if err then
          state.client_rows[client.id] = {}
          schedule_render(bufnr, state)
          return
        end

        local rows = group_lenses(result)
        state.client_rows[client.id] = rows
        schedule_render(bufnr, state)

        if client:supports_method(Methods.codeLens_resolve, bufnr) then
          for _, row_lenses in pairs(rows) do
            for _, lens in ipairs(row_lenses) do
              if not lens.command then
                resolve_lens(client, bufnr, state, seq, tick, lens)
              end
            end
          end
        end
      end, bufnr)
    end
  end

  if not requested then
    clear_extmarks(bufnr)
  end
end

---@param bufnr integer
local function enable_builtin(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    vim.lsp.codelens.enable(true, { bufnr = bufnr })
  end
end

---@param bufnr integer
local function disable_builtin(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    vim.lsp.codelens.enable(false, { bufnr = bufnr })
  end
end

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

function M.refresh(bufnr)
  refresh_now(bufnr)
end

---@param bufnr integer
---@return boolean
function M.is_active(bufnr)
  local state = get_state(bufnr)
  return state ~= nil and has_contexts(state)
end

---@param filter? vim.lsp.codelens.get.Filter
---@return vim.lsp.codelens.get.Result[]
function M.get(filter)
  vim.validate('filter', filter, 'table', true)
  filter = filter or {}

  local bufnr = vim._resolve_bufnr(filter.bufnr)
  local state = get_state(bufnr)
  if not state then
    return {}
  end

  local result = {}
  for client_id, rows in pairs(state.client_rows) do
    if not filter.client_id or filter.client_id == client_id then
      for _, lenses in pairs(rows) do
        for _, lens in ipairs(lenses) do
          result[#result + 1] = {
            client_id = client_id,
            lens = lens,
          }
        end
      end
    end
  end

  table.sort(result, function(a, b)
    if a.client_id ~= b.client_id then
      return a.client_id < b.client_id
    end

    local a_start = a.lens.range.start
    local b_start = b.lens.range.start
    if a_start.line ~= b_start.line then
      return a_start.line < b_start.line
    end
    if a_start.character ~= b_start.character then
      return a_start.character < b_start.character
    end

    local a_title = a.lens.command and a.lens.command.title or ''
    local b_title = b.lens.command and b.lens.command.title or ''
    return a_title < b_title
  end)

  return result
end

---@param bufnr integer
---@param key string
---@param placement 'eol'
function M.set_context(bufnr, key, placement)
  if placement ~= 'eol' or not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local state = ensure_state(bufnr)
  if state.contexts[key] == placement then
    return
  end

  -- The first active context takes ownership from the built-in provider.
  -- Additional contexts share the same cached state and render pass.
  local was_inactive = not has_contexts(state)
  state.contexts[key] = placement

  if was_inactive then
    disable_builtin(bufnr)
    refresh_now(bufnr)
  else
    render(bufnr, state)
  end
end

---@param bufnr integer
---@param key string
function M.clear_context(bufnr, key)
  local state = get_state(bufnr)
  if not state or not state.contexts[key] then
    return
  end

  state.contexts[key] = nil
  if has_contexts(state) then
    render(bufnr, state)
    return
  end

  M.detach_all(bufnr)
  enable_builtin(bufnr)
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

api.nvim_create_autocmd({ 'LspAttach', 'LspDetach' }, {
  group = augroup,
  callback = function(args)
    local state = get_state(args.buf)
    if state and has_contexts(state) then
      M.schedule_refresh(args.buf)
    end
  end,
})

return M
