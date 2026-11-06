-- Run through tests/run-tool-install.py so downloads never touch the real installation.
assert(vim.env.XDG_DATA_HOME:find('nvim%-tool%-install%-'), 'Use the isolated test runner')
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)
for _, name in ipairs({ 'mason.nvim', 'nvim-lspconfig', 'nvim-treesitter' }) do
  local path = vim.fs.joinpath(vim.env.NVIM_TEST_PLUGIN_DIR, name)
  assert(vim.fn.isdirectory(path) == 1, 'Missing plugin checkout: ' .. path)
  vim.opt.runtimepath:append(path)
end
vim.opt.swapfile = false
vim.opt.undofile = false
vim.cmd('filetype on')
require('mason').setup()

local registry = require('configs.lsp')
for name, config in pairs(registry.servers) do
  vim.lsp.config(name, config)
end
require('features.language_install').setup()
-- UI grammars have separate unit coverage; this test compiles only the opened language.
package.loaded['configs.plugins.noice'] = { parsers = {} }
require('configs.plugins.nvim-treesitter')
local mason = require('mason-registry')
local ts = require('nvim-treesitter')
assert(vim.tbl_isempty(mason.get_installed_package_names()))
assert(vim.tbl_isempty(ts.get_installed('parsers')))

local project = vim.fs.joinpath(vim.env.XDG_DATA_HOME, 'project')
vim.fn.mkdir(project, 'p')
vim.fn.writefile(
  { '[project]', 'name = "install-test"', 'version = "0.1.0"' },
  project .. '/pyproject.toml'
)
vim.fn.writefile({ '{"name":"unopened-node-project"}' }, project .. '/package.json')
vim.cmd.cd(project)
vim.wait(100, function()
  return false
end)
assert(
  vim.tbl_isempty(mason.get_installed_package_names()),
  'Project markers must not prewarm tools'
)

vim.cmd.edit(project .. '/main.py')
local buf = vim.api.nvim_get_current_buf()
assert(vim.bo[buf].filetype == 'python', 'Filetype detection did not run')
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'print("on demand")' })
local attaches = {}
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    assert(event.buf == buf, 'Unexpected attachment')
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    attaches[client.name] = (attaches[client.name] or 0) + 1
  end,
})
local ready = vim.wait(180000, function()
  return attaches.pyright == 1
    and attaches.ruff == 1
    and vim.treesitter.highlighter.active[buf] ~= nil
end, 50)
assert(ready, 'Timed out: ' .. vim.inspect({
  attaches = attaches,
  clients = #vim.lsp.get_clients(),
  parser = vim.treesitter.language.add('python'),
  packages = mason.get_installed_package_names(),
}))
local packages = mason.get_installed_package_names()
table.sort(packages)
assert(vim.deep_equal({ 'pyright', 'ruff' }, packages), vim.inspect(packages))
assert(
  vim.deep_equal({ 'python' }, ts.get_installed('parsers')),
  vim.inspect(ts.get_installed('parsers'))
)

-- Repeated FileType must reuse native clients and the installed parser.
vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
vim.wait(200, function()
  return false
end)
assert(attaches.pyright == 1 and attaches.ruff == 1, vim.inspect(attaches))
assert(#vim.lsp.get_clients({ bufnr = buf }) == 2)
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
vim.wait(2000, function()
  return #vim.lsp.get_clients() == 0
end, 20)
print('PASS: empty startup; only Python packages/parser; first-buffer attachment; client reuse')
