local M = {}

M.OS = vim.loop.os_uname().sysname
M.IS_MAC = M.OS == 'Darwin'
M.IS_LINUX = M.OS == 'Linux'
M.IS_WINDOWS = M.OS:find 'Windows' and true or false
M.IS_WSL = M.IS_LINUX and vim.loop.os_uname().release:find 'Microsoft' and true or false

local function mason_path()
   if M.IS_WINDOWS then
      return vim.env.HOME .. '/AppData/Local/nvim-data/mason/'
   else
      return vim.env.HOME .. '/.local/share/nvim/mason/'
   end
end

local function rust_analyzer_cmd()
   if M.IS_WINDOWS then
      return M.MASON_PATH .. 'packages/' .. 'rust-analyzer/rust-analyzer.exe'
   else
      return M.MASON_PATH .. 'bin/' .. 'rust-analyzer'
   end
end

local function codelldb_exetension_path()
   return M.MASON_PATH .. 'packages/' .. 'codelldb/extension/'
end

local function codelldb_path()
   if M.IS_WINDOWS then
      return M.MASON_PATH .. 'bin/' .. 'codelldb.cmd'
   else
      return codelldb_exetension_path() .. 'adapter/codelldb'
   end
end

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

return M
