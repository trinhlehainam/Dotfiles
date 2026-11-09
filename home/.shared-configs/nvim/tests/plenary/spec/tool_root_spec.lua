describe('optional language project detection', function()
  local root, buf, original_home, original_rtp, original_executable, original_start, original_normalize
  local function write(path, value)
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.fn.writefile({ value }, path)
  end
  before_each(function()
    original_home, original_rtp = vim.uv.os_homedir, vim.o.runtimepath
    original_executable, original_start = vim.fn.executable, vim.lsp.rpc.start
    original_normalize = vim.fs.normalize
    root = vim.fn.tempname()
    vim.fn.mkdir(root .. '/repo/src', 'p')
    vim.fn.mkdir(root .. '/repo/.git', 'p')
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, root .. '/repo/src/file.ts')
  end)
  after_each(function()
    vim.uv.os_homedir, vim.o.runtimepath = original_home, original_rtp
    vim.fn.executable, vim.lsp.rpc.start = original_executable, original_start
    vim.fs.normalize = original_normalize
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(root, 'rf')
  end)
  it('finds a config above a file', function()
    write(root .. '/repo/biome.json', '{}')
    assert.equals(root .. '/repo', require('utils.tool_root').find(buf, { 'biome.json' }))
  end)
  it('stops at repository boundaries, including worktree git files', function()
    vim.fn.delete(root .. '/repo/.git', 'd')
    write(root .. '/repo/.git', 'gitdir: elsewhere')
    write(root .. '/biome.json', '{}')
    assert.is_nil(require('utils.tool_root').find(buf, { 'biome.json' }))
  end)
  it('supports Tailwind v4 package dependencies without a config file', function()
    write(root .. '/repo/package.json', '{"devDependencies":{"tailwindcss":"^4"}}')
    assert.equals(root .. '/repo', require('utils.tool_root').find(buf, {}, 'tailwindcss'))
  end)
  it('ignores mentions outside dependency fields and malformed manifests', function()
    write(root .. '/repo/package.json', '{"description":"tailwindcss"}')
    assert.is_nil(require('utils.tool_root').find(buf, {}, 'tailwindcss'))
    write(root .. '/repo/package.json', '{invalid')
    assert.is_nil(require('utils.tool_root').find(buf, {}, 'tailwindcss'))
  end)
  it('uses the nearest matching root in a monorepo and observes changed manifests', function()
    write(root .. '/repo/biome.json', '{}')
    write(root .. '/repo/src/biome.json', '{}')
    assert.equals(root .. '/repo/src', require('utils.tool_root').find(buf, { 'biome.json' }))
    vim.fn.delete(root .. '/repo/src/biome.json')
    assert.equals(root .. '/repo', require('utils.tool_root').find(buf, { 'biome.json' }))
  end)

  it('stops at home even when the platform returns backslashes', function()
    vim.fn.delete(root .. '/repo/.git', 'd')
    write(root .. '/biome.json', '{}')
    vim.uv.os_homedir = function()
      return ((root .. '/repo'):gsub('/', '\\'))
    end
    vim.fs.normalize = function(path, opts)
      return original_normalize(path, vim.tbl_extend('force', opts or {}, { win = true }))
    end
    assert.is_nil(require('utils.tool_root').find(buf, { 'biome.json' }))
  end)

  it('preserves upstream Biome monorepo roots and the project-pinned binary', function()
    local lspconfig = vim.env.LSPCONFIG_DIR or (vim.fn.stdpath('data') .. '/lazy/nvim-lspconfig')
    vim.opt.runtimepath:append(lspconfig)
    write(root .. '/repo/pnpm-lock.yaml', '')
    write(root .. '/repo/biome.json', '{}')
    write(root .. '/repo/src/biome.json', '{"root":false,"extends":"//"}')
    local language = require('configs.lsp.biome')
    assert.is_true(language.condition(buf))
    local config =
      vim.tbl_deep_extend('force', dofile(lspconfig .. '/lsp/biome.lua'), language.servers.biome)
    local resolved
    config.root_dir(buf, function(dir)
      resolved = dir
    end)
    assert.equals(root .. '/repo', resolved)
    local binary = root .. '/repo/node_modules/.bin/biome'
    vim.fn.executable = function(path)
      return path == binary and 1 or 0
    end
    local command
    vim.lsp.rpc.start = function(cmd)
      command = cmd
      return {}
    end
    config.cmd({}, { root_dir = resolved })
    assert.equals(binary, command[1])
  end)
end)
