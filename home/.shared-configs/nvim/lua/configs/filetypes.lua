vim.filetype.add({
  pattern = {
    ['.*/dot_.*'] = function(path, bufnr)
      -- Keep template detection on the original name (dot_env.tmpl, not .env.tmpl).
      if path:match('%.tmpl$') then
        return
      end
      -- Decode chezmoi path components as deployed names.
      local target = path:gsub('/dot_', '/.')
      local filetype, on_detect, is_fallback =
        vim.filetype.match({ filename = target, buf = bufnr >= 0 and bufnr or nil })
      -- Let the outer matcher preserve generic guesses as overridable fallbacks.
      if not is_fallback then
        return filetype, on_detect
      end
    end,
  },
})
