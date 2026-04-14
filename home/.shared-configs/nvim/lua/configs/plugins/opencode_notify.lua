local M = {}

---@class dotfiles.OpencodeNotifySession
---@field cwd? string
---@field model? string
---@field last_text? string
---@field last_tool? string

local function trim(text)
  return text:gsub('^%s+', ''):gsub('%s+$', '')
end

local function project_name(directory)
  if type(directory) ~= 'string' then
    return ''
  end

  return directory:gsub('[\\/]+$', ''):match('([^/\\]+)$') or ''
end

local function clip(text, max)
  if type(text) ~= 'string' then
    return nil
  end

  local compact = trim(text:gsub('%s+', ' '))
  if #compact <= max then
    return compact
  end

  return compact:sub(1, max - 3) .. '...'
end

local function permission_body(permission)
  if type(permission.title) == 'string' and permission.title ~= '' then
    return permission.title
  end

  local kind = permission.type or permission.permission or 'permission'
  local pattern = '*'
  if type(permission.pattern) == 'table' then
    pattern = table.concat(permission.pattern, ', ')
  elseif type(permission.pattern) == 'string' then
    pattern = permission.pattern
  elseif type(permission.patterns) == 'table' then
    pattern = table.concat(permission.patterns, ', ')
  end

  return ('%s (%s)'):format(kind, pattern)
end

function M.setup()
  local notify_bin = vim.fn.expand('~/.local/bin/agent-notify')
  ---@type table<string, dotfiles.OpencodeNotifySession>
  local sessions = {}
  local notified_permissions = {}

  local function get_session(session_id, cwd)
    if type(session_id) ~= 'string' or session_id == '' then
      return { cwd = cwd or vim.fn.getcwd(-1, -1) }
    end

    local session = sessions[session_id]
    if session then
      return session
    end

    session = { cwd = cwd }
    sessions[session_id] = session
    return session
  end

  local function title_for(session)
    local project = project_name(session.cwd)
    if project ~= '' then
      return 'OpenCode - ' .. project
    end

    return 'OpenCode'
  end

  local function notify(session, body)
    if body == nil or body == '' or vim.fn.executable(notify_bin) ~= 1 then
      return
    end

    vim.fn.jobstart({ notify_bin, '-t', title_for(session), '-b', body }, { detach = true })
  end

  local function notify_permission(permission)
    if type(permission) ~= 'table' then
      return
    end

    if permission.id and notified_permissions[permission.id] then
      return
    end

    if permission.id then
      notified_permissions[permission.id] = true
    end

    notify(
      get_session(permission.sessionID, nil),
      'Permission required: ' .. permission_body(permission)
    )
  end

  vim.api.nvim_create_autocmd('User', {
    group = vim.api.nvim_create_augroup('DotfilesOpencodeAgentNotify', { clear = true }),
    pattern = 'OpencodeEvent:*',
    callback = function(args)
      local data = args.data or {}
      local event = data.event
      if type(event) ~= 'table' or type(event.properties) ~= 'table' then
        return
      end

      local properties = event.properties

      if event.type == 'message.updated' and type(properties.info) == 'table' then
        local info = properties.info
        if info.role == 'assistant' then
          local path = info.path or {}
          local session = get_session(info.sessionID, path.cwd)
          session.cwd = path.cwd
          if type(info.providerID) == 'string' and type(info.modelID) == 'string' then
            session.model = info.providerID .. '/' .. info.modelID
          end
        end
        return
      end

      if event.type == 'message.part.updated' and type(properties.part) == 'table' then
        local part = properties.part
        local session = get_session(part.sessionID, nil)

        if part.type == 'text' and type(part.time) == 'table' and part.time['end'] then
          session.last_text = clip(part.text, 140)
        end

        if part.type == 'tool' and type(part.state) == 'table' then
          local status = part.state.status
          if status == 'completed' or status == 'error' then
            session.last_tool = ('%s %s'):format(part.tool or 'tool', status)
          end
        end
        return
      end

      if event.type == 'permission.asked' or event.type == 'permission.updated' then
        notify_permission(properties)
        return
      end

      if event.type == 'session.error' then
        local session = get_session(properties.sessionID, nil)
        local body = session.last_text and ('Session error after: ' .. session.last_text)
          or 'Session error'
        notify(session, body)
        if type(properties.sessionID) == 'string' then
          sessions[properties.sessionID] = nil
        end
        return
      end

      if event.type == 'session.idle' then
        local session = get_session(properties.sessionID, nil)
        local detail = session.last_text or session.last_tool or 'Task complete'
        local body = session.model and (session.model .. ' - ' .. detail) or detail
        notify(session, body)
        if type(properties.sessionID) == 'string' then
          sessions[properties.sessionID] = nil
        end
      end
    end,
  })
end

return M
