local M = {}

function M.extend_list(destination, source)
  for _, value in ipairs(source) do
    table.insert(destination, value)
  end
end

return M
