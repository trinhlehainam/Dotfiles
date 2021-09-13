require'nvim-treesitter.configs'.setup {
    highlight = {
        enable = true,
    }
}

vim.cmd(
[[
autocmd FileType python highlight link TSKeywordOperator Keyword
autocmd FileType cpp highlight link TSKeywordOperator Keyword
]]
)
