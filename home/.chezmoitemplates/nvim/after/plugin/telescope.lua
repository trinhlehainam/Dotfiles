if vim.g.vscode then
	return
end

local hastelescope, _ = pcall(require, "telescope")
if not hastelescope then
	return
end

-- See `:help telescope` and `:help telescope.setup()`
require("telescope").setup({
	defaults = {
		mappings = {
			i = {
				["<C-u>"] = false,
				["<C-d>"] = false,
			},
		},
	},
})

-- Enable telescope fzf native, if installed
pcall(require("telescope").load_extension, "fzf")
pcall(require("telescope").load_extension, "ui-select")

local haschezmoiext, chezmoi_ext = pcall(require("telescope").load_extension, "chezmoi")
if haschezmoiext then
	vim.keymap.set("n", "<leader>cz", chezmoi_ext.find_files, { desc = "[C]hezmoi Find Files" })
end

local hasnoice, noice = pcall(require, "noice")
local hasnoiceext, _ = pcall(require("telescope").load_extension, "noice")
if hasnoiceext and hasnoice then
	vim.keymap.set("n", "<leader>nt", function()
		noice.cmd("telescope")
	end, { desc = "[N]oice [T]elescope" })
end

local builtin = require("telescope.builtin")
-- See `:help telescope.builtin`
vim.keymap.set("n", "<leader>f.", builtin.oldfiles, { desc = "[F]ind recently[.] opened files" })
vim.keymap.set("n", "<leader><space>", builtin.buffers, { desc = "[ ] Find existing buffers" })
vim.keymap.set("n", "<leader>/", function()
	-- You can pass additional configuration to telescope to change theme, layout, etc.
	builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		-- winblend = 10,
		previewer = false,
	}))
end, { desc = "[/] Fuzzily search in current buffer" })

vim.keymap.set("n", "<leader>ff", function()
	builtin.find_files({
		hidden = true,
		-- needed to exclude some files & dirs from general search
		-- when not included or specified in .gitignore
		find_command = {
			"rg",
			"--files",
			"--hidden",
			"--glob=!**/.git/*",
			"--glob=!**/.idea/*",
			"--glob=!**/.vscode/*",
			"--glob=!**/node_modules/*",
			"--glob=!**/build/*",
			"--glob=!**/dist/*",
			"--glob=!**/yarn.lock",
			"--glob=!**/package-lock.json",
			"--glob=!**/lazy-lock.json",
		},
	})
end, { desc = "[F]ind [F]iles" })
vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "[F]ind [K]eymaps" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "[F]ind [H]elp" })
vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "[F]ind current [W]ord" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "[F]ind by [G]rep" })
vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "[F]ind [D]iagnostics" })
vim.keymap.set("n", "<leader>fc", builtin.colorscheme, { desc = "[F]ind [C]olorscheme" })
