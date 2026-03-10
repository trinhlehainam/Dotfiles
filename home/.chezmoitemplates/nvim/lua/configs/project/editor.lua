local buffer_utils = require('utils.buffer')
local detector = require('configs.project.detector')
local options = require('configs.project.options')

local M = {}

-- Keep the old editor entrypoint as a thin facade so reload/setup callers do
-- not need to know about the detector/options split.

function M.invalidate()
  detector.invalidate()
  options.invalidate()
end

function M.refresh_open_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if buffer_utils.is_regular(bufnr) then
      detector.redetect_filetype(bufnr)
      options.apply_filetype_settings(bufnr)
    end
  end
end

---@param bufnr integer
---@return boolean|nil
function M.get_format_on_save(bufnr)
  return options.get_filetype_format_on_save(bufnr)
end

---@param group integer
function M.setup(group)
  detector.setup(group)
  options.setup(group)
end

return M
