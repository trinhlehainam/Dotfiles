---@alias custom.LspConfig.Setup fun(capabilities: lsp.ClientCapabilities, on_attach: fun(client: lsp.Client, bufnr: integer))

---@class custom.LspConfig
---@field server? string
---@field setup? custom.LspConfig.Setup
---@field use_setup boolean
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
---@field lspconfig custom.LspConfig
---@field dapconfig custom.DapConfig
---@field formatterconfig custom.FormatterConfig
---@field linterconfig custom.LinterConfig
---@field after_lspconfig? fun()
local M = {}

---@return custom.LanguageSetting
function M:new()
	local t = setmetatable({}, { __index = M })
	t.lspconfig = {
		server = nil,
		setup = nil,
		use_setup = true,
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
	t.after_lspconfig = nil
	return t
end

return M
