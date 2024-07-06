---@class custom.LanguageSetting
local M = {}

---@return custom.LanguageSetting
function M:new()
	local t = setmetatable({}, { __index = M })
	t.treesitter = {
		filetypes = nil,
	}
	t.lspconfig = {
		server = nil,
		setup = nil,
		use_masonlsp_setup = true,
		settings = {},
	}
	t.lspconfigs = {}
	t.dapconfig = {
		type = nil,
		setup = nil,
		use_masondap_default_setup = false,
	}
	t.formatterconfig = {
		servers = nil,
		formatters_by_ft = nil,
	}
	t.linterconfig = {
		servers = nil,
		linters_by_ft = nil,
	}
	t.after_masonlsp_setup = nil
	return t
end

return M
