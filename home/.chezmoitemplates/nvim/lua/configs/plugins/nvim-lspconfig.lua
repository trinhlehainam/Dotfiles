-- Brief aside: **What is LSP?**
--
-- LSP is an initialism you've probably heard, but might not understand what it is.
--
-- LSP stands for Language Server Protocol. It's a protocol that helps editors
-- and language tooling communicate in a standardized fashion.
--
-- In general, you have a "server" which is some tool built to understand a particular
-- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
-- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
-- processes that communicate with some "client" - in this case, Neovim!
--
-- LSP provides Neovim with features like:
--  - Go to definition
--  - Find references
--  - Autocompletion
--  - Symbol Search
--  - and more!
--
-- Thus, Language Servers are external tools that must be installed separately from
-- Neovim. This is where `mason` and related plugins come into play.
--
-- If you're wondering about lsp vs treesitter, you can check out the wonderfully
-- and elegantly composed help section, `:help lsp-vs-treesitter`

--  This function gets run when an LSP attaches to a particular buffer.
--    That is to say, every time a new file is opened that is associated with
--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
--    function will be executed to configure the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    -- NOTE: Remember that Lua is a real programming language, and as such it is possible
    -- to define small helper and utility functions so you don't have to repeat yourself.
    --
    -- In this case, we create a function that lets us more easily define mappings specific
    -- for LSP related items. It sets the mode, buffer and description for us each time.
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    -- Find references for the word under your cursor.
    map('grr', function()
      Snacks.picker.lsp_references()
    end, '[G]oto [R]eferences')

    -- Jump to the implementation of the word under your cursor.
    --  Useful when your language has ways of declaring types without an actual implementation.
    map('gri', function()
      Snacks.picker.lsp_implementations()
    end, '[G]oto [I]mplementation')

    -- Jump to the definition of the word under your cursor.
    --  This is where a variable was first declared, or where a function is defined, etc.
    --  To jump back, press <C-t>.
    map('grd', function()
      Snacks.picker.lsp_definitions()
    end, '[G]oto [D]efinition')

    -- WARN: This is not Goto Definition, this is Goto Declaration.
    --  For example, in C this would take you to the header.
    map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    -- Fuzzy find all the symbols in your current document.
    --  Symbols are things like variables, functions, types, etc.
    map('gO', function()
      Snacks.picker.lsp_symbols()
    end, 'Open Document Symbols')

    -- Fuzzy find all the symbols in your current workspace.
    --  Similar to document symbols, except searches over your entire project.
    map('gW', function()
      Snacks.picker.lsp_workspace_symbols()
    end, 'Open Workspace Symbols')

    -- Jump to the type of the word under your cursor.
    --  Useful when you're not sure what type a variable is and you want to see
    --  the definition of its *type*, not where it was *defined*.
    map('grt', function()
      Snacks.picker.lsp_type_definitions()
    end, '[G]oto [T]ype Definition')

    ---@param client vim.lsp.Client
    ---@param method vim.lsp.protocol.Method
    ---@param bufnr? integer some lsp support methods only in specific files
    ---@return boolean
    local function client_supports_method(client, method, bufnr)
      return client:supports_method(method, bufnr)
    end

    -- The following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    --    See `:help CursorHold` for information about when this is executed
    --
    -- When you move your cursor, the highlights will be cleared (the second autocommand).
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if
      client
      and client_supports_method(
        client,
        vim.lsp.protocol.Methods.textDocument_documentHighlight,
        event.buf
      )
    then
      local highlight_augroup =
        vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds({ group = 'kickstart-lsp-highlight', buffer = event2.buf })
        end,
      })
    end

    -- The following code creates a keymap to toggle inlay hints in your
    -- code, if the language server you are using supports them
    --
    -- This may be unwanted, since they displace some of your code
    if
      client
      and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf)
    then
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
      end, '[T]oggle Inlay [H]ints')
    end
  end,
})

-- Diagnostic Config
-- See :help vim.diagnostic.Opts
local diagnostic_jump_ns = vim.api.nvim_create_namespace('on_diagnostic_jump')
vim.diagnostic.config({
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = false,
  virtual_lines = {
    current_line = true,
  },
  -- NOTE: `vim.diagnostic.config({ jump = { on_jump = ... } })` is only available starting in Neovim 0.12.
  -- Reference: https://github.com/neovim/neovim/issues/33154
  jump = (function()
    if vim.fn.has('nvim-0.12') == 1 then
      return {
        on_jump = function(diagnostic, bufnr)
          if not diagnostic then
            return
          end

          vim.diagnostic.show(
            diagnostic_jump_ns,
            bufnr,
            { diagnostic },
            { virtual_lines = false, virtual_text = false }
          )
        end,
      }
    end
  end)(),
})

-- Diagnostic keymaps

-- Diagnostic handlers can be toggled. Follow `:help diagnostic-toggle-virtual-lines-example`.
vim.keymap.set('n', 'gK', function()
  local new_config = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = new_config })
end, { desc = 'Toggle diagnostic virtual_lines' })

vim.keymap.set('n', 'gk', function()
  local current = vim.diagnostic.config().virtual_lines
  if not current then
    vim.notify('diagnostic virtual_lines is disabled (toggle with gK)', vim.log.levels.WARN)
    return
  end

  local current_line = type(current) == 'table' and current.current_line or false
  vim.diagnostic.config({ virtual_lines = { current_line = not current_line } })
end, { desc = 'Toggle diagnostic virtual_lines current_line' })

vim.keymap.set('n', '[d', function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = 'Go to next diagnostic message' })
vim.keymap.set(
  'n',
  '<leader>e',
  vim.diagnostic.open_float,
  { desc = 'Open floating diagnostic message' }
)

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. Available keys are:
--  - cmd (table): Override the default command used to start the server
--  - filetypes (table): Override the default list of associated filetypes for the server
--  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
--  - settings (table): Override the default settings passed when initializing the server.
--        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
--- @type table<string, vim.lsp.Config>
local servers = {}

-- Safely load LSP configurations
local log = require('utils.log')
local lspconfigs = {}
local ok, lsp_config = pcall(require, 'configs.lsp')
if ok then
  lspconfigs = lsp_config.lspconfigs or {}
else
  log.warn('Failed to load configs.lsp module for lspconfig')
end

for _, lspconfig in pairs(lspconfigs) do
  local server_name = lspconfig.server
  -- Only add valid server configurations
  if type(server_name) == 'string' and server_name ~= '' then
    servers[server_name] = lspconfig.config
  end
end

-- Installed LSPs are configured and enabled automatically with mason-lspconfig
-- The loop below is for overriding the default configuration of LSPs with the ones in the servers table
for server_name, config in pairs(servers) do
  vim.lsp.enable(server_name)
  vim.lsp.config(server_name, config)
end

-- Language server for Postgres written in Rust
-- NOTE: This framework is not production ready yet, check back later
-- lspconfig.postgres_lsp.setup{}
--
