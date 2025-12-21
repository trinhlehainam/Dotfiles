local M = {}

function M.trim(value)
  return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

function M.trim_right(value)
  return (value:gsub('%s+$', ''))
end

function M.percent_decode(value)
  return (value:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

return M
