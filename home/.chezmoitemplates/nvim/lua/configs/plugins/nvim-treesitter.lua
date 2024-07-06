local treesitter = require("nvim-treesitter.configs")

local ensure_installed = {
	-- #region Required
	-- A list of parser names, or "all" (the five listed parsers should always be installed)
	"c",
	"lua",
	"vim",
	"vimdoc",
	"query",
	-- #endregion Required

	"dockerfile",
	"sql",
}

local has_noiceconfig, noiceconfig = pcall(require, "configs.plugins.noice")
if has_noiceconfig and vim.islist(noiceconfig.parsers) then
	ensure_installed = vim.list_extend(ensure_installed, require("configs.plugins.noice").parsers)
end

local treesitters = require("configs.lsp").treesitters

for _, config in ipairs(treesitters) do
	local filetypes = config.filetypes
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
