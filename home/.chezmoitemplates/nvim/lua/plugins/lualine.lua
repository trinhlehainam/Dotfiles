-- Add multiple components in one section and setup there're options by putting them in tables
-- See 'lualine.util.loader' source file for more information how components are loaded to module
-- NOTE: lua count index of a table and an array from 1 (not 0)
-- {
--    -- 1: Component's name as String
--    'component_name',
--    -- 2: Options
--    ...
-- }
--
-- Example:
-- sections = {
--    lualine_a = {
--       {
--          'encoding',
--          ...
--       },
--       {
--          'fileformat',
--          symbols = {
--             unix = ' LF',         -- e712
--             dos = ' CRLF',        -- e70f
--             mac = ' CR',          -- e711
--          }
--       },
--       {
--          'filetype',
--          ...
--       }
--    }
-- }

return {
	-- Set lualine as statusline
	"nvim-lualine/lualine.nvim",
	-- See `:help lualine.txt`
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
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
		})
	end,
}
