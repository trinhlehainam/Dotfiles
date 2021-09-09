--[[ vim.opt.listchars = {
    eol = "↴",
}

vim.opt.list = true ]]

require("indent_blankline").setup {
    -- space_char_blankline = " ",
    -- show_end_of_line = true,
    char = "|",
    buftype_exclude = {"terminal"},
}
