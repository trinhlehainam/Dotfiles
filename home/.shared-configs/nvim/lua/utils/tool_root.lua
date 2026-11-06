local M = {}

---Find an optional tool's project without walking outside its repository.
---Read manifests as JSON; a mention in scripts/descriptions is not a dependency.
---@param bufnr integer
---@param markers string[]
---@param dependency? string
---@return string?
function M.find(bufnr, markers, dependency)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
  while dir do
    for _, marker in ipairs(markers) do
      if vim.uv.fs_stat(vim.fs.joinpath(dir, marker)) then
        return dir
      end
    end
    if dependency then
      local file = io.open(vim.fs.joinpath(dir, 'package.json'), 'r')
      if file then
        local text = file:read('*a')
        file:close()
        local ok, package = pcall(vim.json.decode, text)
        if ok and type(package) == 'table' then
          for _, field in ipairs({
            'dependencies',
            'devDependencies',
            'peerDependencies',
            'optionalDependencies',
          }) do
            if type(package[field]) == 'table' and type(package[field][dependency]) == 'string' then
              return dir
            end
          end
        end
      end
    end
    if
      vim.uv.fs_stat(dir .. '/.git')
      or vim.uv.fs_stat(dir .. '/.jj')
      or dir == vim.fs.normalize(vim.uv.os_homedir())
    then
      break
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

return M
