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
		require("lualine").setup({
			options = {
				icons_enabled = true,
				-- theme = 'onedark',
				component_separators = "|",
				section_separators = "",
			},
			sections = {
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
					-- TODO: Use to debug Codeium status
					" %3{codeium#GetStatusString()}",
				},
			},
		})
	end,
}
