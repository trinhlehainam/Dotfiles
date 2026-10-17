-- Used by benchmark-nvim-startup.py before init.lua, never by the normal config.
local start = vim.uv.hrtime()
local marks = {}
local snapshots = {}
local input_samples = {}
local dispatch_delays = {}

local function mark(name)
  marks[name] = (vim.uv.hrtime() - start) / 1e6
end

local function snapshot(name)
  mark(name)
  local plugins = {}
  local config = package.loaded['lazy.core.config']
  for key, plugin in pairs(config and config.plugins or {}) do
    if plugin._.loaded then
      plugins[key] = plugin._.loaded
    end
  end
  snapshots[name] = plugins
  local clients = {}
  if package.loaded['vim.lsp'] then
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0, _uninitialized = true })) do
      clients[#clients + 1] = { name = client.name, initialized = client.initialized }
    end
  end
  local stats = package.loaded['lazy.stats']
  vim.fn.writefile({
    vim.json.encode({
      marks = marks,
      input_samples = input_samples,
      dispatch_delays = dispatch_delays,
      clients = clients,
      plugins = snapshots,
      startup_cpu_ms = stats and stats.stats().startuptime or nil,
      messages = vim.api.nvim_exec2('messages', { output = true }).output,
      error = vim.v.errmsg,
      filetype = vim.bo.filetype,
      syntax = vim.bo.syntax,
    }),
  }, vim.env.NVIM_BENCH_RESULT)
end

-- Exercise editing after startup while ordinary asynchronous plugin work continues.
-- These samples include Neovim input handling and redraw, not terminal display latency.
local runtime_started = false
local step, input_start, expected_dispatch = 0, nil, nil
local namespace = vim.api.nvim_create_namespace('dotfiles-benchmark')
local function next_input()
  if expected_dispatch then
    dispatch_delays[#dispatch_delays + 1] = math.max(0, (vim.uv.hrtime() - expected_dispatch) / 1e6)
  end
  step = step + 1
  if step > 41 then
    snapshot('runtime_done')
    vim.cmd('qa!')
    return
  end
  input_start = vim.uv.hrtime()
  local key
  if step <= 20 then
    key = 'x'
  elseif step == 21 then
    key = '<Esc>'
  elseif step % 2 == 0 then
    key = 'h'
  else
    key = 'l'
  end
  vim.api.nvim_input(key)
end
vim.on_key(function()
  if not input_start then
    return
  end
  local started = input_start
  input_start = nil
  vim.schedule(function()
    vim.cmd('redraw')
    local elapsed = (vim.uv.hrtime() - started) / 1e6
    if step ~= 21 then
      input_samples[#input_samples + 1] =
        { phase = step <= 20 and 'typing' or 'cursor', ms = elapsed }
    end
    expected_dispatch = vim.uv.hrtime() + 30e6
    vim.defer_fn(next_input, 30)
  end)
end, namespace)
local function exercise_editor()
  if runtime_started or not (marks.ready and marks.first_edit) then
    return
  end
  runtime_started = true
  next_input()
end

vim.o.swapfile = false
vim.o.shadafile = 'NONE'
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    mark('vim_enter')
  end,
})
vim.api.nvim_create_autocmd('UIEnter', {
  once = true,
  callback = function()
    snapshot('ui_enter')
    -- Keep running after the first edit to expose queued startup work as well.
    vim.schedule(function()
      vim.defer_fn(function()
        snapshot('ready')
        exercise_editor()
      end, 200)
    end)
  end,
})
vim.api.nvim_create_autocmd('User', {
  pattern = 'VeryLazy',
  once = true,
  callback = function()
    vim.schedule(function()
      mark('very_lazy')
    end)
  end,
})
vim.api.nvim_create_autocmd('InsertEnter', {
  once = true,
  callback = function()
    mark('insert_enter')
    vim.schedule(function()
      snapshot('insert_ready')
    end)
  end,
})

vim.api.nvim_create_autocmd('TextChangedI', {
  once = true,
  callback = function()
    vim.schedule(function()
      snapshot('first_edit')
      exercise_editor()
    end)
  end,
})

-- Installation is separate from startup of an already-provisioned editor.
package.preload['configs.plugins.mason-tool-installer'] = function()
  local installer = require('mason-tool-installer')
  local setup = installer.setup
  installer.setup = function(opts)
    opts.run_on_start = false
    setup(opts)
  end
  dofile(vim.fn.stdpath('config') .. '/lua/configs/plugins/mason-tool-installer.lua')
  installer.setup = setup
end
package.preload['mason-nvim-dap.ensure_installed'] = function()
  return function() end
end
