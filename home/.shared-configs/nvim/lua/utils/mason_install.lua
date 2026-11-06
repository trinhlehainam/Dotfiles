local registry = require('mason-registry')
local M = {}
local pending = {} ---@type table<string, fun(success: boolean)[]>
local failed = {} ---@type table<string, boolean>
local queued = {} ---@type table<string, boolean>
local refreshing = false

---@param name string
---@return boolean
function M.is_ready(name)
  -- Mason promotes the package directory before linking binaries; it writes the receipt last.
  local path = require('mason-core.installer.InstallLocation').global():package(name)
  return vim.uv.fs_stat(vim.fs.joinpath(path, 'mason-receipt.json')) ~= nil
end

local function finish(name, success)
  local callbacks = pending[name] or {}
  pending[name] = nil
  queued[name] = nil
  if success then
    failed[name] = nil
  elseif #callbacks > 0 and not failed[name] then
    failed[name] = true
    vim.notify(
      ('Could not install %s. See :MasonLog; retry with :MasonInstall %s'):format(name, name),
      vim.log.levels.WARN
    )
  end
  for _, callback in ipairs(callbacks) do
    callback(success)
  end
end

-- Registry events also cover installs already running in :Mason and manual retries.
registry:on(
  'package:install:success',
  vim.schedule_wrap(function(pkg)
    finish(pkg.name, true)
  end)
)
registry:on(
  'package:install:failed',
  vim.schedule_wrap(function(pkg)
    finish(pkg.name, false)
  end)
)

local function flush()
  -- Always supply a callback: refresh() without one blocks Neovim.
  -- https://github.com/mason-org/mason.nvim/blob/main/doc/mason.txt
  local on_refresh = vim.schedule_wrap(function()
    refreshing = false
    local batch = queued
    queued = {}
    for name in pairs(batch) do
      if M.is_ready(name) then
        finish(name, true)
      else
        local ok, pkg = pcall(registry.get_package, name)
        if not ok then
          finish(name, false)
        elseif not pkg:is_installing() then
          local started = pcall(pkg.install, pkg)
          if not started then
            finish(name, false)
          end
        end
      end
    end
  end)
  local ok, err = pcall(registry.refresh, on_refresh)
  if not ok then
    vim.notify('Mason registry refresh failed: ' .. tostring(err), vim.log.levels.WARN)
    -- The cached registry can still install tools; never leave the queue locked.
    on_refresh()
  end
end

---Install missing packages once per session; :MasonInstall can retry failures.
---The callback always runs on the main loop, after every package has settled.
---@param packages string[]
---@param on_done fun(success: boolean)
function M.ensure(packages, on_done)
  local remaining, success = #packages, true
  if remaining == 0 then
    vim.schedule(function()
      on_done(true)
    end)
    return
  end
  local function settled(ok)
    success = success and ok
    remaining = remaining - 1
    if remaining == 0 then
      vim.schedule(function()
        on_done(success)
      end)
    end
  end

  for _, name in ipairs(packages) do
    if M.is_ready(name) then
      settled(true)
    elseif failed[name] then
      settled(false)
    elseif pending[name] then
      table.insert(pending[name], settled)
    else
      pending[name] = { settled }
      queued[name] = true
    end
  end
  if next(queued) and not refreshing then
    refreshing = true
    -- Collect simultaneous FileType and server requests into one registry refresh.
    vim.schedule(flush)
  end
end

return M
