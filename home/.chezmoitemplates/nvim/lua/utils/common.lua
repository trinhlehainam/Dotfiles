local M = {}

local log = require('utils.log')

M.OS = vim.uv.os_uname().sysname
M.IS_MAC = M.OS == 'Darwin'
M.IS_LINUX = M.OS == 'Linux'
M.IS_WINDOWS = M.OS:find('Windows') and true or false
M.IS_WSL = M.IS_LINUX
  and (vim.uv.os_uname().release:lower():find('microsoft') ~= nil
    or vim.uv.os_uname().release:lower():find('wsl') ~= nil)

---@param mode string|string[]
---@param bufnr number
---@param prefix? string
---@return fun(keys: string, func: function|string, desc?: string)
function M.create_map(mode, bufnr, prefix)
  return function(keys, func, desc)
    vim.keymap.set(mode, keys, func, {
      buffer = bufnr,
      desc = (prefix and desc) and (prefix .. ': ' .. desc) or desc,
    })
  end
end

---@param bufnr number
---@param prefix? string
---@return fun(keys: string, func: function|string, desc?: string)
function M.create_nmap(bufnr, prefix)
  return M.create_map('n', bufnr, prefix or 'LSP')
end

---@param bufnr number
---@param prefix? string
---@return fun(keys: string, func: function|string, desc?: string)
function M.create_vmap(bufnr, prefix)
  return M.create_map('v', bufnr, prefix or 'LSP')
end

---@param modname string
---@return string
function M.modname_to_dir_path(modname)
  local path = string.gsub(modname, '%.', '/')
  return vim.fn.stdpath('config') .. '/lua/' .. path
end

--- Loads all Lua modules from a directory.
--- Only loads `.lua` files directly in the directory (not subdirectories or init.lua patterns).
--- Each module is keyed by its filename without the `.lua` extension.
---@param directory string Absolute path to a directory inside `/lua/`
---@param ignore_mods? string[] List of module names (without `.lua`) to skip
---@return table<string, any> Map of module name to loaded module
function M.load_mods_in_dir(directory, ignore_mods)
  local mods = {}
  local mods_dirname = directory:match('/lua/(.-)/?$')

  if not mods_dirname then
    log.error('load_mods_in_dir: could not extract module path from: ' .. directory)
    return mods
  end

  local ok, files = pcall(vim.fn.readdir, directory)
  if not ok or not files then
    log.warn('load_mods_in_dir: could not read directory: ' .. directory)
    return mods
  end

  -- Build ignore set for O(1) lookup
  local ignore_set = {}
  if ignore_mods then
    for _, m in ipairs(ignore_mods) do
      ignore_set[m] = true
    end
  end

  for _, filename in ipairs(files) do
    local modname = filename:match('^(.+)%.lua$')
    if modname and not ignore_set[modname] then
      local full_modname = mods_dirname:gsub('/', '.') .. '.' .. modname
      local success, mod = pcall(require, full_modname)
      if success then
        mods[modname] = mod
      else
        log.warn('load_mods_in_dir: failed to load ' .. full_modname .. ': ' .. tostring(mod))
      end
    end
  end

  return mods
end

---@param modname string
---@param ignore_mods? string[]
---@return table<string, any>
function M.load_mods(modname, ignore_mods)
  local mods_dir = M.modname_to_dir_path(modname)
  return M.load_mods_in_dir(mods_dir, ignore_mods)
end

---@param extension? string
---@return string
function M.create_temp_file(extension)
  local temp_file = os.tmpname()

  if not extension or extension == '' then
    return temp_file
  end

  local temp_file_with_extension = temp_file .. '.' .. extension
  local success, err = os.rename(temp_file, temp_file_with_extension)
  if not success then
    log.warn('create_temp_file: failed to rename temp file: ' .. tostring(err))
    return temp_file
  end

  return temp_file_with_extension
end

--- Encodes data to base64 string.
--- Fallback order:
---   1. vim.base64.encode (Neovim 0.9+, fastest)
---   2. External `base64` command (slower, spawns process)
---   3. LuaJIT bit library implementation (pure Lua fallback)
---@param data string
---@return string
local function base64_encode(data)
  if vim.base64 and vim.base64.encode then
    return vim.base64.encode(data)
  end

  if vim.fn.executable('base64') == 1 then
    return (vim.fn.system({ 'base64' }, data) or ''):gsub('%s+$', '')
  end

  local ok, bit = pcall(require, 'bit')
  if not ok then
    return ''
  end

  local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local bytes = { data:byte(1, #data) }
  local out = {}

  for i = 1, #bytes, 3 do
    local a = bytes[i]
    local b = bytes[i + 1]
    local c = bytes[i + 2]
    local triple = bit.bor(bit.lshift(a, 16), bit.lshift(b or 0, 8), c or 0)

    local i1 = bit.band(bit.rshift(triple, 18), 0x3F) + 1
    local i2 = bit.band(bit.rshift(triple, 12), 0x3F) + 1
    local i3 = bit.band(bit.rshift(triple, 6), 0x3F) + 1
    local i4 = bit.band(triple, 0x3F) + 1

    out[#out + 1] = alphabet:sub(i1, i1)
    out[#out + 1] = alphabet:sub(i2, i2)
    out[#out + 1] = b and alphabet:sub(i3, i3) or '='
    out[#out + 1] = c and alphabet:sub(i4, i4) or '='
  end

  return table.concat(out)
end

-- Emits the same OSC 1337 sequence used by WezTerm's shell integration
-- helper `__wezterm_set_user_var`, so you can read it on the WezTerm side
-- via `pane:get_user_vars()`.
-- Reference: https://wezterm.org/config/lua/pane/get_user_vars.html
-- Tmux passthrough reference: https://github.com/tmux/tmux/wiki/FAQ#what-is-the-passthrough-escape-sequence-and-how-do-i-use-it
---@param name string
---@param value string
---@return boolean sent
function M.wezterm_set_user_var(name, value)
  if #vim.api.nvim_list_uis() == 0 then
    return false
  end

  local encoded = base64_encode(value)
  if encoded == '' and value ~= '' then
    return false
  end

  local esc = string.char(27)
  local bel = string.char(7)

  local osc = string.format('%s]1337;SetUserVar=%s=%s%s', esc, name, encoded, bel)

  if vim.env.TMUX ~= nil then
    osc = string.format('%sPtmux;%s%s%s\\', esc, esc, osc:gsub(esc, esc .. esc), esc)
  end

  pcall(vim.api.nvim_chan_send, vim.v.stderr, osc)
  return true
end

return M
