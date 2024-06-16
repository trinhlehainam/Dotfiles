local common = require("utils.common")

-- TODO: need to install luarocks and rocks dependencies in Windows
if common.IS_WINDOWS then
	return {}
end

return {
	"rest-nvim/rest.nvim",
	ft = "http",
	dependencies = { "luarocks.nvim", "nvim-telescope/telescope.nvim", "williamboman/mason.nvim" },
	config = function()
		local mason_utils = require("utils.mason")
		local log = require("utils.log")
		local mason_path = mason_utils.get_mason_path()

		local function json_format_cmd()
			if not mason_utils.has_mason() then
				log.error("mason.nvim is not installed")
				return "jq"
			end

			local jq_path = mason_utils.get_mason_package_path("jq")

			if not jq_path then
				return "jq"
			end

			if common.IS_WINDOWS then
				return mason_path .. "/jq.cmd"
			else
				return mason_path .. "/bin/jq"
			end
		end

		---@param body string
		local function format_html_body(body)
			if not mason_utils.has_mason() then
				log.error("mason.nvim is not installed")
				return "jq"
			end

			local prettierd_path = mason_utils.get_mason_package_path("prettierd")

			if not prettierd_path then
				return body, { found = false, name = "prettierd" }
			end

			local function prettierd_cmd()
				if common.IS_WINDOWS then
					return mason_path .. "/bin/prettierd.cmd"
				else
					return mason_path .. "/bin/prettierd"
				end
			end

			if vim.fn.executable(prettierd_cmd()) == 0 then
				return body, { found = false, name = "prettierd" }
			end

			local temp_file = common.create_temp_file("html")
			local file = io.open(temp_file, "w")
			if not file then
				return body, { found = false, name = "prettierd" }
			end
			file:write(body)
			file:close()

			-- NOTE: get sdtout of formatted file from prettierd
			-- https://github.com/fsouza/prettierd?tab=readme-ov-file#using-in-the-command-line-with-nodejs
			local fmt_cmd = "cat " .. temp_file .. " | " .. prettierd_cmd() .. " " .. temp_file
			local fmt_body = vim.fn.system(fmt_cmd)

			os.remove(temp_file)

			return fmt_body, { found = true, name = "prettierd" }
		end
		require("rest-nvim").setup({
			result = {
				behavior = {
					formatters = {
						json = json_format_cmd(),
						html = format_html_body,
					},
				},
			},
		})

		local hasrestext, restext = pcall(require("telescope").load_extension, "rest")
		if hasrestext then
			vim.keymap.set("n", "<leader>fre", restext.select_env, { desc = "[F]ind [R]est [E]nvironment" })
		end

		vim.keymap.set("n", "<leader>rr", "<cmd>Rest run<cr>", { desc = "[R]est [R]un" })
		vim.keymap.set("n", "<leader>rl", "<cmd>Rest run last<cr>", { desc = "[R]est Run [L]ast" })
	end,
}
