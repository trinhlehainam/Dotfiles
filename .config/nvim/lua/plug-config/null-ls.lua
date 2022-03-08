local null_ls = require("null-ls")

local code_actions = null_ls.builtins.code_actions
local diagnostics = null_ls.builtins.diagnostics
local formatting = null_ls.builtins.formatting
local hover = null_ls.builtins.hover
local completion = null_ls.builtins.completion

null_ls.setup({
    debug = false,
    sources = {
        formatting.prettier.with({extra_args = {'--tab-width 4', '--use-tabs'}}),
    }
})
