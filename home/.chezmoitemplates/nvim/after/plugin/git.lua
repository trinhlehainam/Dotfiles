if vim.g.vscode then
	return
end

local log = require("utils.log")
local hasneogit, neogit = pcall(require, "neogit")
local hasdiffview, diffview = pcall(require, "diffview")

if not hasneogit then
	log.error("neogit is not installed")
	return
end

if not hasdiffview then
	log.error("diffview is not installed")
	return
end

neogit.setup({
	mappings = {
		-- Setting any of these to `false` will disable the mapping.
		popup = {
			["l"] = false,
			["L"] = "LogPopup",
		},
		status = {
			["j"] = false,
			["k"] = "MoveDown",
			["l"] = "MoveUp",
		},
	},
})

local actions = require("diffview.actions")
diffview.setup({
	keymaps = {
		file_panel = {
			{ "n", "j", false },
			{ "n", ";", false },
			{ "n", "k", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
			{ "n", "l", actions.prev_entry, { desc = "Bring the cursor to the previous file entry" } },
		},
	},
})

vim.keymap.set("n", "<leader>gs", neogit.open, { desc = "[S]how [G]it", silent = true, noremap = true })
vim.keymap.set("n", "<leader>gc", ":Neogit commit<CR>", { desc = "[G]it [C]ommit", silent = true, noremap = true })
vim.keymap.set("n", "<leader>gp", ":Neogit pull<CR>", { desc = "[G]it [P]ull", silent = true, noremap = true })
vim.keymap.set("n", "<leader>gP", ":Neogit push<CR>", { desc = "[G]it [P]ush", silent = true, noremap = true })
vim.keymap.set(
	"n",
	"<leader>gb",
	":Telescope git_branches<CR>",
	{ desc = "[G]it [B]ranches", silent = true, noremap = true }
)

local hasocto, octo = pcall(require, "octo")
if not hasocto then
	log.error("octo is not installed")
	return
end
octo.setup()
