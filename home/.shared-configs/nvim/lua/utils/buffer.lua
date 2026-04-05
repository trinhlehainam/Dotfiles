local M = {}

---@param bufnr integer
---@return string
function M.name(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  return vim.api.nvim_buf_get_name(bufnr)
end

---@param bufnr integer
---@return boolean
function M.is_regular(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == ''
end

return M
