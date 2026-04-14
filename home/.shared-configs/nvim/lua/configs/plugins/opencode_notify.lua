local M = {}

function M.setup()
  local notify_bin = vim.fn.expand('~/.local/bin/agent-notify')
  if vim.fn.executable(notify_bin) ~= 1 then
    return
  end

  vim.api.nvim_create_autocmd('User', {
    group = vim.api.nvim_create_augroup('DotfilesOpencodeAgentNotify', { clear = true }),
    pattern = 'OpencodeEvent:*',
    callback = function(args)
      local event = args.data and args.data.event
      if type(event) ~= 'table' then
        return
      end

      local ok, json = pcall(vim.json.encode, event)
      if not ok then
        return
      end

      vim.fn.jobstart(
        { notify_bin, '--format', 'opencode-event', '--stdin' },
        { stdin = json, detach = true }
      )
    end,
  })
end

return M
