return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    -- NOTE: avoid conflict with tree-sitter installation
    -- Tree-sitter installs tree-sitter-nu every startup time,
    -- Avoid switch to nu shell before installing tree-sitter-nu
    event = 'VeryLazy',
    config = function()
      if vim.fn.has('win32') == 1 then
        -- NOTE: because scoop doesn't update nushell frequently, use powershell instead
        -- if vim.fn.executable("nu") == 1 then
        -- 	-- Ref: https://github.com/neovim/neovim/issues/19648#issuecomment-1212295560
        -- 	local nushell_options = {
        -- 		shell = "nu",
        -- 		shellcmdflag = "-c",
        -- 		shellquote = "",
        -- 		shellxquote = "",
        -- 	}
        --
        -- 	for option, value in pairs(nushell_options) do
        -- 		vim.opt[option] = value
        -- 	end
        -- else
        -- Change default shell to powershell on Windows
        -- Ref: https://github.com/akinsho/toggleterm.nvim/wiki/Tips-and-Tricks#using-toggleterm-with-powershell
        local powershell_options = {
          shell = vim.fn.executable('pwsh') == 1 and 'pwsh' or 'powershell',
          shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;',
          shellredir = '-RedirectStandardOutput %s -NoNewWindow -Wait',
          shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode',
          shellquote = '',
          shellxquote = '',
        }

        for option, value in pairs(powershell_options) do
          vim.opt[option] = value
        end
      end

      require('toggleterm').setup({
        open_mapping = { [[<c-\>]], [[<c-¥>]] },
      })

      vim.keymap.set('n', '<leader>ftm', ':TermSelect<CR>', { desc = '[F]ind [T]er[m]inal' })
      vim.keymap.set('n', '<leader>trn', ':ToggleTermSetName', { desc = '[T]oggleTerm [R]e[n]ame' })
      function _G.set_terminal_keymaps()
        local opts = { buffer = 0, silent = true }
        vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
        vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
        vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
      end

      -- if you only want these mappings for toggle term use term://*toggleterm#* instead
      vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')
    end,
  },
}
