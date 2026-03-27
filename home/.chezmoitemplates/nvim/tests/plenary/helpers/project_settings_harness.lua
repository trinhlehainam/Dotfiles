local uv = vim.uv

local M = {}

local setup_done = false
local outside_dir

local function join(...)
  return table.concat({ ... }, '/')
end

local function ensure_dir(path)
  vim.fn.mkdir(path, 'p')
end

local function write_file(path, content)
  ensure_dir(vim.fs.dirname(path))
  local file = assert(io.open(path, 'w'))
  file:write(content)
  file:close()
end

local function setup_indent_race_fixture(group)
  vim.api.nvim_create_autocmd('BufReadPost', {
    group = group,
    pattern = '*.php',
    callback = function(args)
      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, 32, false)

      for _, line in ipairs(lines) do
        if line:match('^\t+') then
          vim.bo[args.buf].expandtab = false
          vim.bo[args.buf].tabstop = 8
          vim.bo[args.buf].shiftwidth = 8
          vim.bo[args.buf].softtabstop = 8
          return
        end

        if line:match('^  +') then
          vim.bo[args.buf].expandtab = true
          vim.bo[args.buf].tabstop = 2
          vim.bo[args.buf].shiftwidth = 2
          vim.bo[args.buf].softtabstop = 2
          return
        end
      end
    end,
  })
end

local function wait_for(message, predicate, timeout)
  local ok = vim.wait(timeout or 1000, function()
    local status, done = pcall(predicate)
    return status and done
  end, 10, false)
  if not ok then
    error(message)
  end
end

function M.setup()
  if setup_done then
    return
  end

  local repo = vim.g.project_settings_test_repo_root
  assert(type(repo) == 'string' and repo ~= '', 'project_settings_test_repo_root is not set')
  assert(uv.fs_stat(join(repo, 'lua', 'configs', 'project', 'init.lua')), 'repo runtime not found')

  vim.opt.runtimepath:prepend(repo)
  vim.cmd('filetype on')

  outside_dir = join(vim.fn.tempname(), 'outside')
  ensure_dir(outside_dir)
  vim.cmd('cd ' .. vim.fn.fnameescape(outside_dir))

  require('configs.project').setup()
  setup_indent_race_fixture(vim.api.nvim_create_augroup('project-settings-test', { clear = true }))
  setup_done = true
end

function M.reset_to_scratch()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  vim.cmd('enew')

  if outside_dir then
    vim.cmd('cd ' .. vim.fn.fnameescape(outside_dir))
  end
end

function M.new_base()
  local base = join(vim.fn.tempname(), 'project-settings-regression')
  ensure_dir(base)
  return base
end

function M.mktemp_root(base, name)
  local root = join(base, name)
  ensure_dir(root)
  return root
end

function M.write_file(path, content)
  write_file(path, content)
end

function M.write_json(path, value)
  write_file(path, vim.json.encode(value))
end

---@param opts { cwd?: string, init: string, args?: string[], env?: table<string, string> }
---@return { code: integer, signal: integer, stdout: string, stderr: string }
function M.run_child_nvim(opts)
  assert(type(opts) == 'table', 'opts must be a table')
  assert(type(opts.init) == 'string' and opts.init ~= '', 'opts.init must be a non-empty string')

  local temp_root = join(vim.fn.tempname(), 'project-settings-child')
  local cache_dir = join(temp_root, 'cache')
  local state_dir = join(temp_root, 'state')
  local init_path = join(temp_root, 'child_init.lua')

  ensure_dir(cache_dir)
  ensure_dir(state_dir)
  write_file(init_path, opts.init)

  local env = vim.tbl_extend('force', vim.fn.environ(), {
    XDG_CACHE_HOME = cache_dir,
    XDG_STATE_HOME = state_dir,
  }, opts.env or {})

  local command = { 'nvim', '--headless', '--noplugin', '-u', init_path }
  for _, arg in ipairs(opts.args or {}) do
    table.insert(command, arg)
  end

  local result = vim
    .system(command, {
      cwd = opts.cwd,
      env = env,
      text = true,
    })
    :wait()

  return {
    code = result.code,
    signal = result.signal,
    stdout = result.stdout or '',
    stderr = result.stderr or '',
  }
end

function M.edit(path)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

function M.wait_for_filetype(bufnr, expected, message)
  wait_for(message, function()
    return vim.bo[bufnr].filetype == expected
  end)
end

function M.read_indent(bufnr)
  return {
    expandtab = vim.bo[bufnr].expandtab,
    tabstop = vim.bo[bufnr].tabstop,
    shiftwidth = vim.bo[bufnr].shiftwidth,
    softtabstop = vim.bo[bufnr].softtabstop,
  }
end

function M.wait_for_indent(bufnr, expected, message)
  wait_for(message, function()
    return vim.deep_equal(M.read_indent(bufnr), expected)
  end)
end

function M.php_defaults()
  return {
    expandtab = vim.filetype.get_option('php', 'expandtab'),
    tabstop = vim.filetype.get_option('php', 'tabstop'),
    shiftwidth = vim.filetype.get_option('php', 'shiftwidth'),
    softtabstop = vim.filetype.get_option('php', 'softtabstop'),
  }
end

function M.reload()
  vim.cmd('ProjectSettingsReload')
end

function M.join(...)
  return join(...)
end

return M
