require'nvim-treesitter.configs'.setup {
    highlight = {
        enable = true,
    }
}

vim.cmd(
[[
autocmd FileType python,cpp highlight link TSKeywordOperator Keyword
]]
)
