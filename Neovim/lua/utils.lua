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

function M.create_nmap(bufnr)
   return function(keys, func, desc)
      if desc then
         desc = 'LSP: ' .. desc
      end

      vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
   end
end

--  This function gets run when an LSP connects to a particular buffer.
function M.on_attach(_, bufnr)
   -- NOTE: Remember that lua is a real programming language, and as such it is possible
   -- to define small helper and utility functions so you don't have to repeat yourself
   -- many times.
   --
   -- In this case, we create a function that lets us more easily define mappings specific
   -- for LSP related items. It sets the mode, buffer and description for us each time.
   local nmap = M.create_nmap(bufnr)

   nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
   nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

   nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
   nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
   nmap('gI', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
   nmap('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
   nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
   nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

   -- See `:help K` for why this keymap
   nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
   nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

   -- Lesser used LSP functionality
   nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
   nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
   nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
   nmap('<leader>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
   end, '[W]orkspace [L]ist Folders')

   -- Create a command `:Format` local to the LSP buffer
   vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
      vim.lsp.buf.format()
   end, { desc = 'Format current buffer with LSP' })
end

function M.modname_to_dir_path(modname)
   local path = string.gsub(modname, '%.', '/')
   return vim.fn.stdpath('config') .. '/lua/' .. path
end

function M.load_mods_in_dir(directory_path, ignore_mods)
   local mods = {}
   local mods_dirname = string.match(directory_path, '/lua/(.-)/?$')
   for _, filename in ipairs(vim.fn.readdir(directory_path)) do
      if filename:match('%.lua$') then
         local modname = filename:match("^(.-)%.lua$")
         if not ignore_mods or not vim.tbl_contains(ignore_mods, modname) then
            mods[modname] = require(mods_dirname .. '.' .. modname)
         end
      end
   end
   return mods
end

function M.load_mods(modname, ignore_mods)
   local mods_dir = M.modname_to_dir_path(modname);
   return M.load_mods_in_dir(mods_dir, ignore_mods)
end

return M
