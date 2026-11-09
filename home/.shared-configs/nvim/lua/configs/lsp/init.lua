local merge_unique = require('utils.common').merge_unique_strings

local languages = {
  'ansible',
  'awk',
  'bash',
  'biome',
  'csharp',
  'css',
  'docker-compose',
  'go',
  'html',
  'jinja',
  'json',
  'lua',
  'markdown',
  'nginx',
  'nushell',
  'php',
  'powershell',
  'python',
  'rust',
  'tailwindcss',
  'typescript',
  'yaml',
}

---@type dotfiles.lsp.Registry
local M = {
  by_filetype = {},
  server_tools = {},
  parsers = {},
  tools = {},
  servers = {},
  formatters = {},
  linters = {},
  lint_on_save = {},
  dap = {},
}
local neotest_factories = {}

for _, name in ipairs(languages) do
  ---@type dotfiles.lsp.Language
  local language = require('configs.lsp.' .. name)
  assert(
    not next(language.tools or {}) or next(language.filetypes or {}),
    'Missing install filetypes: ' .. name
  )
  for _, filetype in ipairs(language.filetypes or {}) do
    M.by_filetype[filetype] = M.by_filetype[filetype] or {}
    table.insert(M.by_filetype[filetype], language)
  end
  for server, tools in pairs(language.server_tools or {}) do
    assert(language.servers and language.servers[server], 'Unknown server owner: ' .. server)
    M.server_tools[server] = tools
    for _, tool in ipairs(tools) do
      assert(vim.tbl_contains(language.tools or {}, tool), 'Missing server tool: ' .. tool)
    end
  end
  M.parsers = merge_unique(M.parsers, language.parsers)
  M.tools = merge_unique(M.tools, language.tools)
  M.tools = merge_unique(M.tools, language.debug_tools)
  M.dap = merge_unique(M.dap, language.dap)

  -- Each server and formatter chain must have one owner.
  for server, config in pairs(language.servers or {}) do
    assert(M.servers[server] == nil, 'Duplicate LSP server: ' .. server)
    M.servers[server] = config
  end
  for filetype, formatters in pairs(language.formatters or {}) do
    assert(M.formatters[filetype] == nil, 'Duplicate formatter filetype: ' .. filetype)
    M.formatters[filetype] = formatters
  end
  for filetype, linters in pairs(language.linters or {}) do
    M.linters[filetype] = merge_unique(M.linters[filetype], linters)
    M.lint_on_save[filetype] = M.lint_on_save[filetype] ~= false and language.lint_on_save ~= false
  end
  if language.neotest then
    table.insert(neotest_factories, language.neotest)
  end
end

---Call after Neotest dependencies load; adapter errors must remain visible.
---@return neotest.Adapter[]
function M.get_neotest_adapters()
  local adapters = {}
  for _, factory in ipairs(neotest_factories) do
    table.insert(adapters, factory())
  end
  return adapters
end

return M
