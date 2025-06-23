-- Stable configuration documentation
-- INFO: https://github.com/Saecki/crates.nvim/wiki/Documentation-v0.6.0

local crates = require('crates')
require("crates").setup {
    lsp = {
        enabled = true,
        on_attach = function(client, bufnr)
            -- the same on_attach function as for your other lsp's
        end,
        actions = true,
        completion = true,
        hover = true,
    },
}

vim.keymap.set('n', '<leader>ct', crates.toggle, { desc = '[C]rates [T]oggle' })
vim.keymap.set('n', '<leader>cr', crates.reload, { desc = '[C]rates [R]eload' })

vim.keymap.set('n', '<leader>cv', crates.show_versions_popup, { desc = '[C]rates [V]ersions' })
vim.keymap.set('n', '<leader>cf', crates.show_features_popup, { desc = '[C]rates [F]eatures' })
vim.keymap.set('n', '<leader>cd', crates.show_dependencies_popup, { desc = '[C]rates [D]ependencies' })

vim.keymap.set('n', '<leader>cu', crates.update_crate, { desc = '[C]rates [U]pdate' })
vim.keymap.set('v', '<leader>cu', crates.update_crates, { desc = '[C]rates [U]pdate' })
vim.keymap.set('n', '<leader>ca', crates.update_all_crates, { desc = '[C]rates Update [A]ll' })
vim.keymap.set('n', '<leader>cU', crates.upgrade_crate, { desc = '[C]rates [U]pgrade' })
vim.keymap.set('v', '<leader>cU', crates.upgrade_crates, { desc = '[C]rates [U]pgrade' })
vim.keymap.set('n', '<leader>cA', crates.upgrade_all_crates, { desc = '[C]rates Upgrade [A]ll' })

vim.keymap.set('n', '<leader>cH', crates.open_homepage, { desc = '[C]rates Open [H]omepage' })
vim.keymap.set('n', '<leader>cR', crates.open_repository, { desc = '[C]rates Open [R]epository' })
vim.keymap.set( 'n', '<leader>cD', crates.open_documentation, { desc = '[C]rates Open [D]ocumentation' })
vim.keymap.set('n', '<leader>cC', crates.open_crates_io, { desc = '[C]rates Open [C]rates' })

-- INFO: https://github.com/Saecki/crates.nvim/wiki/Documentation-v0.6.0#show-appropriate-documentation-in-cargotoml
local function show_documentation()
  local filetype = vim.bo.filetype
  if vim.tbl_contains({ 'vim', 'help' }, filetype) then
    vim.cmd('h ' .. vim.fn.expand('<cword>'))
  elseif vim.tbl_contains({ 'man' }, filetype) then
    vim.cmd('Man ' .. vim.fn.expand('<cword>'))
  elseif vim.fn.expand('%:t') == 'Cargo.toml' and require('crates').popup_available() then
    require('crates').show_popup()
  else
    vim.lsp.buf.hover()
  end
end

vim.keymap.set('n', 'K', show_documentation, { silent = true })
