require'nvim-treesitter.configs'.setup {
    highlight = {
        enable = true,
    }
}

vim.cmd(
[[
autocmd FileType python,cpp,javascript,typescript highlight link TSKeywordOperator Keyword
]]
)
