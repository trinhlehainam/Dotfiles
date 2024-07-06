local function get_codeium_status()
	return "{…} " .. vim.fn["codeium#GetStatusString"]()
end

-- Add vim visual multi statusline into lualine
-- INFO: https://github.com/nvim-lualine/lualine.nvim/issues/951
local function get_vim_visual_multi()
	local result = vim.fn["VMInfos"]()
	-- local current = result.current
	-- local total = result.total
	local ratio = result.ratio
	local patterns = result.patterns
	-- local status = result.status
	return "%#St_InsertMode# "
		.. " MULTI "
		.. "%#St_lspWarning#  "
		.. patterns[1]
		.. " "
		.. "%#StText#"
		.. " "
		.. ratio
end

-- INFO: https://github.com/SmiteshP/nvim-navic?tab=readme-ov-file#lualine
local function get_navic_status()
	local hasnavic, navic = pcall(require, "nvim-navic")
	if not hasnavic then
		return ""
	end
	return navic.get_location()
end

local function is_navic_available()
	local hasnavic, navic = pcall(require, "nvim-navic")
	if not hasnavic then
		return false
	end
	return navic.is_available()
end

require("lualine").setup({
	options = {
		icons_enabled = true,
		-- theme = 'onedark',
		component_separators = "|",
		section_separators = "",
	},
	sections = {
		lualine_a = {
			{
				"mode",
				fmt = function(mode)
					return vim.b["visual_multi"] and get_vim_visual_multi() or mode
				end,
			},
		},
		lualine_x = {
			"encoding",
			{
				"fileformat",
				symbols = {
					unix = " LF", -- e712
					dos = " CRLF", -- e70f
					mac = " CR", -- e711
				},
			},
			"filetype",
			-- https://github.com/Exafunction/codeium.vim/issues/100
			{ get_codeium_status },
		},
	},
	-- OR in winbar
	winbar = {
		lualine_c = {
			{
				function()
					return get_navic_status()
				end,
				cond = function()
					return is_navic_available()
				end,
			},
		},
	},
})
