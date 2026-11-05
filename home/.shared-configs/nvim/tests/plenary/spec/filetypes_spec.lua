describe('Chezmoi filetype detection', function()
  local bufnr
  local original_minimal

  local function detect(filename)
    return vim.filetype.match({ filename = filename, buf = bufnr })
  end

  before_each(function()
    original_minimal = vim.g.dotfiles_minimal
    vim.g.dotfiles_minimal = true
    require('configs.bootstrap').setup()
    require('configs.lsp.bash')
    require('configs.lsp.go')
    bufnr = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.g.dotfiles_minimal = original_minimal
  end)

  for _, case in ipairs({
    { 'dot_tmux.conf', '.tmux.conf', 'tmux' },
    { 'dot_bashrc', '.bashrc', 'sh' },
    { 'dot_bash_aliases', '.bash_aliases', 'sh' },
    { 'dot_zshrc', '.zshrc', 'zsh' },
    { 'dot_zsh_aliases', '.zsh_aliases', 'zsh' },
    { 'dot_zprofile', '.zprofile', 'zsh' },
    { 'dot_ideavimrc', '.ideavimrc', 'vim' },
    { 'dot_gitconfig', '.gitconfig', 'gitconfig' },
  }) do
    it('detects ' .. case[1] .. ' like ' .. case[2], function()
      local target_ft = detect(case[2])
      local source_ft = detect(case[1])
      assert.equals(case[3], target_ft)
      assert.equals(case[3], source_ft)
    end)
  end

  it('decodes directory components for path-dependent detection', function()
    local target_ft = detect('home/.config/git/config')
    local source_ft = detect('home/dot_config/git/config')
    assert.equals('gitconfig', target_ft)
    assert.equals('gitconfig', source_ft)
  end)

  it('preserves Bash detection callbacks', function()
    local filetype, on_detect = detect('dot_bashrc')

    assert.equals('sh', filetype)
    assert.equals('function', type(on_detect))
    on_detect(bufnr)
    assert.equals(1, vim.b[bufnr].is_bash)
  end)

  it('keeps Go template detection and ordinary extensions', function()
    assert.equals('gotmpl', detect('home/dot_config/nushell/config.nu.tmpl'))
    assert.equals('lua', detect('home/dot_config/wezterm/wezterm.lua'))
    assert.equals('yaml', detect('home/dot_config/workmux/config.yaml'))
    assert.equals('json', detect('home/dot_config/Vimium/vimium-options.json'))
  end)

  it('keeps template detection before decoding dotfile names', function()
    for _, name in ipairs({ 'dot_env.tmpl', 'dot_env.local.tmpl' }) do
      assert.equals('gotmpl', detect(name))
      assert.equals('gotmpl', vim.filetype.match({ filename = name }))
    end
  end)

  it('falls back to content for unknown dotfiles', function()
    assert.is_nil(detect('dot_unknown_filetype'))
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '#!/usr/bin/env python3' })
    assert.equals('python', detect('dot_unknown_filetype'))
  end)

  it('preserves overridable content fallback', function()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '# comment' })
    local target_ft, _, target_fallback = detect('.unknownrc')
    local source_ft, _, source_fallback = detect('dot_unknownrc')

    assert.equals('conf', target_ft)
    assert.equals(target_ft, source_ft)
    assert.is_true(target_fallback)
    assert.is_true(source_fallback)
  end)

  it('supports filename-only detection', function()
    assert.equals('tmux', vim.filetype.match({ filename = 'dot_tmux.conf' }))
    assert.equals('sh', vim.filetype.match({ filename = 'dot_bashrc' }))
  end)

  it('sets the buffer filetype through normal file events', function()
    vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. '/dot_tmux.conf')
    vim.api.nvim_exec_autocmds('BufNewFile', { buffer = bufnr })

    assert.equals('tmux', vim.bo[bufnr].filetype)
  end)
end)
