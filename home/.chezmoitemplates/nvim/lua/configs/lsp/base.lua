---@alias custom.LspConfig.Setup fun(capabilities: lsp.ClientCapabilities, on_attach: fun(client: lsp.Client, bufnr: integer))

---@class custom.TreeSitter
---@field filetypes? string[]

---@class custom.LspConfig
---@field server? string
---@field setup? custom.LspConfig.Setup
---@field use_masonlsp_setup boolean
---@field settings table

---@class custom.DapConfig
---@field type? string
---@field configs? Configuration[]

---@class custom.FormatterConfig
---@field servers? string[]
---@field formatters_by_ft? table<string, table>

---@class custom.LinterConfig
---@field servers? string[]
---@field linters_by_ft? table<string, table>

---@class custom.LanguageSetting
---@field treesitter custom.TreeSitter
---@field lspconfig custom.LspConfig
---@field dapconfig custom.DapConfig
---@field formatterconfig custom.FormatterConfig
---@field linterconfig custom.LinterConfig
---@field after_masonlsp_setup? fun()
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
	t.dapconfig = {
		type = nil,
		configs = nil,
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
