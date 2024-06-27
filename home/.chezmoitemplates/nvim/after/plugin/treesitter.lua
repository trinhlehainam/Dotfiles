if vim.g.vscode then
	return
end

local log = require("utils.log")
pcall(require("nvim-treesitter.install").update({ with_sync = true }))

local hastreesitter, treesitter = pcall(require, "nvim-treesitter.configs")
if not hastreesitter then
	log.error("nvim-treesitter is not installed")
	return
end

local ensure_installed = {
	"c",
	"cpp",
	"c_sharp",
	"dockerfile",
	"sql",
}

local hasnoice, _ = pcall(require, "noice")
if hasnoice then
	local noice_parsers = { "vim", "regex", "lua", "bash", "markdown", "markdown_inline" }
	ensure_installed = vim.list_extend(ensure_installed, noice_parsers)
end

local language_settings = require("configs.lsp").language_settings

for _, settings in pairs(language_settings) do
	local filetypes = settings.treesitter.filetypes
	if filetypes ~= nil and vim.islist(filetypes) then
		vim.list_extend(ensure_installed, filetypes)
	end
end

-- See `:help nvim-treesitter`
treesitter.setup({
	-- Add languages to be installed here that you want installed for treesitter
	ensure_installed = ensure_installed,

	-- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)
	auto_install = false,

	highlight = {
		enable = true,
		additional_vim_regex_highlighting = { "markdown", "markdown_inline" },
	},
	indent = { enable = true, disable = { "python" } },
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<c-space>",
			node_incremental = "<c-space>",
			scope_incremental = "<c-s>",
			node_decremental = "<M-space>",
		},
	},
	textobjects = {
		select = {
			enable = true,
			lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
			keymaps = {
				-- You can use the capture groups defined in textobjects.scm
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
			},
		},
		move = {
			enable = true,
			set_jumps = true, -- whether to set jumps in the jumplist
			goto_next_start = {
				["]m"] = "@function.outer",
				["]]"] = "@class.outer",
			},
			goto_next_end = {
				["]M"] = "@function.outer",
				["]["] = "@class.outer",
			},
			goto_previous_start = {
				["[m"] = "@function.outer",
				["[["] = "@class.outer",
			},
			goto_previous_end = {
				["[M"] = "@function.outer",
				["[]"] = "@class.outer",
			},
		},
		swap = {
			enable = true,
			swap_next = {
				["<leader>a"] = "@parameter.inner",
			},
			swap_previous = {
				["<leader>A"] = "@parameter.inner",
			},
		},
	},
	fold = {
		fold_one_line_after = true,
	},
})
