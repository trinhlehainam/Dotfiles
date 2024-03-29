local M = {}

M.OS = vim.loop.os_uname().sysname
M.IS_MAC = M.OS == 'Darwin'
M.IS_LINUX = M.OS == 'Linux'
M.IS_WINDOWS = M.OS:find 'Windows' and true or false
M.IS_WSL = M.IS_LINUX and vim.loop.os_uname().release:find 'Microsoft' and true or false

---@return string
local function mason_path()
   if M.IS_WINDOWS then
      return vim.env.HOME .. '/AppData/Local/nvim-data/mason/'
   else
      return vim.env.HOME .. '/.local/share/nvim/mason/'
   end
end

---@return string
local function rust_analyzer_cmd()
   if M.IS_WINDOWS then
      return M.MASON_PATH .. 'packages/' .. 'rust-analyzer/rust-analyzer.exe'
   else
      return M.MASON_PATH .. 'bin/' .. 'rust-analyzer'
   end
end

---@return string
local function codelldb_exetension_path()
   return M.MASON_PATH .. 'packages/' .. 'codelldb/extension/'
end

---@return string
local function codelldb_path()
   if M.IS_WINDOWS then
      return M.MASON_PATH .. 'bin/' .. 'codelldb.cmd'
   else
      return codelldb_exetension_path() .. 'adapter/codelldb'
   end
end

---@return string
local function liblldb_path()
   if M.IS_WINDOWS then
      return ''
   else
      return codelldb_exetension_path() .. 'lldb/lib/liblldb.so'
   end
end

M.MASON_PATH = mason_path()
M.RUST_ANALYZER_CMD = rust_analyzer_cmd()
M.CODELLDB_PATH = codelldb_path()
M.LIBLLDB_PATH = liblldb_path()

---@param bufnr number
---@return fun(keys: string, func: function, desc: string)
function M.create_nmap(bufnr)
   return function(keys, func, desc)
      if desc then
         desc = 'LSP: ' .. desc
      end

      vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
   end
end

---@param modname string
---@return string
function M.modname_to_dir_path(modname)
   local path = string.gsub(modname, '%.', '/')
   return vim.fn.stdpath('config') .. '/lua/' .. path
end

---@param directory string
---@param ignore_mods string[]
---@return table<string, any>
function M.load_mods_in_dir(directory, ignore_mods)
   local mods = {}
   local mods_dirname = string.match(directory, '/lua/(.-)/?$')
   for _, filename in ipairs(vim.fn.readdir(directory)) do
      if filename:match('%.lua$') then
         local modname = filename:match("^(.-)%.lua$")
         if not ignore_mods or not vim.tbl_contains(ignore_mods, modname) then
            mods[modname] = require(mods_dirname .. '.' .. modname)
         end
      end
   end
   return mods
end

---@param modname string
---@param ignore_mods string[]
---@return table<string, any>
function M.load_mods(modname, ignore_mods)
   local mods_dir = M.modname_to_dir_path(modname);
   return M.load_mods_in_dir(mods_dir, ignore_mods)
end

return M
