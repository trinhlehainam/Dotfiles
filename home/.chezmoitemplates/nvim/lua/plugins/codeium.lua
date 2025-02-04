return {
  'Exafunction/codeium.vim',
  event = 'BufEnter',
  config = function()
    -- NOTE:
    -- Problem:
    -- https://github.com/Exafunction/codeium.vim/issues/35
    -- Codeium sometimes downloads wrong binary in or binary not executable
    -- codeium.vim doesn't detect Windows WSL and cheat it as Windows
    -- so codeium.vim downloads Windows `.exe` binary in WSL
    -- Solve:
    -- Goto: https://github.com/Exafunction/codeium and download (use `wget` or `curl` in Ubuntu) .gz binary manually
    -- extract .gz binary with `tar` or `gunzip`
    -- Override binary in `~/.codeium/bin/<sha>/`

    -- Change '<C-g>' here to any keycode you like.
    -- vim.keymap.set('i', '<C-g>', function () return vim.fn['codeium#Accept']() end, { expr = true })
    -- vim.keymap.set('i', '<c-;>', function() return vim.fn['codeium#CycleCompletions'](1) end, { expr = true })
    -- vim.keymap.set('i', '<c-,>', function() return vim.fn['codeium#CycleCompletions'](-1) end, { expr = true })
    -- vim.keymap.set('i', '<c-x>', function() return vim.fn['codeium#Clear']() end, { expr = true })
    -- vim.keymap.set('i', '<leader>c', function() return vim.fn['codeium#Chat']() end, { expr = true })
  end,
}
